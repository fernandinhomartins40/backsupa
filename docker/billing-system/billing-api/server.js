#!/usr/bin/env node
/**
 * Billing API Server - Sistema de cobrança independente para BaaS Supabase
 * Integração com Stripe e rate limiting baseado em métricas
 */

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const compression = require('compression');

const app = express();
const PORT = process.env.BILLING_PORT || 3002;

// Database connection
const masterDb = new Pool({
    connectionString: process.env.MASTER_DB_URL || 'postgresql://postgres:postgres@localhost:5432/supabase_master',
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Middleware
app.use(helmet());
app.use(compression());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Rate limiting middleware baseado em uso da organização
const createRateLimit = (limitKey, multiplier = 1) => {
    return async (req, res, next) => {
        try {
            const orgId = req.headers['x-org-id'] || req.query.org_id || req.body.org_id;
            
            if (!orgId) {
                return res.status(400).json({ error: 'Organization ID required' });
            }

            // Verificar se pode fazer request
            const result = await masterDb.query(
                'SELECT increment_api_usage($1) as allowed',
                [orgId]
            );

            if (!result.rows[0].allowed) {
                return res.status(429).json({
                    error: 'Rate limit exceeded',
                    message: 'API request limit reached for current hour',
                    type: 'rate_limit_exceeded'
                });
            }

            req.orgId = orgId;
            next();
        } catch (error) {
            console.error('Rate limit check error:', error);
            // Em caso de erro, permitir request mas logar
            next();
        }
    };
};

// Health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        timestamp: new Date().toISOString(),
        service: 'billing-api',
        version: '1.0.0'
    });
});

// Obter planos disponíveis
app.get('/api/plans', async (req, res) => {
    try {
        const result = await masterDb.query(`
            SELECT id, name, price_monthly, price_yearly, limits, features, is_active
            FROM plans 
            WHERE is_active = true 
            ORDER BY price_monthly ASC
        `);

        res.json({
            success: true,
            plans: result.rows
        });
    } catch (error) {
        console.error('Error fetching plans:', error);
        res.status(500).json({ error: 'Failed to fetch plans' });
    }
});

// Obter subscription atual da organização
app.get('/api/subscription', createRateLimit('subscription_read'), async (req, res) => {
    try {
        const { orgId } = req;

        const result = await masterDb.query(`
            SELECT 
                s.*,
                p.name as plan_name,
                p.limits,
                p.features,
                p.price_monthly,
                p.price_yearly
            FROM subscriptions s
            JOIN plans p ON s.plan_id = p.id
            WHERE s.organization_id = $1 AND s.status = 'active'
        `, [orgId]);

        if (result.rows.length === 0) {
            // Retornar plano Free padrão
            const freeResult = await masterDb.query(`
                SELECT * FROM plans WHERE name = 'Free'
            `);
            
            return res.json({
                success: true,
                subscription: null,
                current_plan: freeResult.rows[0]
            });
        }

        res.json({
            success: true,
            subscription: result.rows[0],
            current_plan: {
                id: result.rows[0].plan_id,
                name: result.rows[0].plan_name,
                limits: result.rows[0].limits,
                features: result.rows[0].features,
                price_monthly: result.rows[0].price_monthly,
                price_yearly: result.rows[0].price_yearly
            }
        });
    } catch (error) {
        console.error('Error fetching subscription:', error);
        res.status(500).json({ error: 'Failed to fetch subscription' });
    }
});

// Obter estatísticas de uso
app.get('/api/usage', createRateLimit('usage_read'), async (req, res) => {
    try {
        const { orgId } = req;
        const { period = 'current_month' } = req.query;

        let periodStart, periodEnd;
        const now = new Date();
        
        switch (period) {
            case 'current_hour':
                periodStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours());
                periodEnd = new Date(periodStart.getTime() + 60 * 60 * 1000);
                break;
            case 'current_day':
                periodStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
                periodEnd = new Date(periodStart.getTime() + 24 * 60 * 60 * 1000);
                break;
            case 'current_month':
            default:
                periodStart = new Date(now.getFullYear(), now.getMonth(), 1);
                periodEnd = new Date(now.getFullYear(), now.getMonth() + 1, 1);
                break;
        }

        const usageResult = await masterDb.query(`
            SELECT 
                metric_type,
                SUM(value) as total_value
            FROM usage_metrics 
            WHERE organization_id = $1 
            AND period_start >= $2 
            AND period_end <= $3
            GROUP BY metric_type
        `, [orgId, periodStart, periodEnd]);

        // Obter rate limiting atual
        const rateLimitResult = await masterDb.query(`
            SELECT api_requests_count, reset_at
            FROM rate_limits 
            WHERE organization_id = $1
        `, [orgId]);

        // Obter limites do plano
        const planResult = await masterDb.query(`
            SELECT plan_name, limits FROM get_organization_plan($1)
        `, [orgId]);

        const usage = {};
        usageResult.rows.forEach(row => {
            usage[row.metric_type] = parseInt(row.total_value);
        });

        const planLimits = planResult.rows[0]?.limits || {};
        const currentRateLimit = rateLimitResult.rows[0] || { api_requests_count: 0 };

        res.json({
            success: true,
            period: {
                type: period,
                start: periodStart,
                end: periodEnd
            },
            usage: {
                api_requests: usage.api_requests || 0,
                storage_bytes: usage.storage_bytes || 0,
                bandwidth_bytes: usage.bandwidth_bytes || 0,
                db_connections: usage.db_connections || 0,
                current_hour_requests: currentRateLimit.api_requests_count
            },
            limits: planLimits,
            rate_limit: {
                current_count: currentRateLimit.api_requests_count,
                limit: planLimits.api_requests_hour || 1000,
                reset_at: currentRateLimit.reset_at
            }
        });
    } catch (error) {
        console.error('Error fetching usage:', error);
        res.status(500).json({ error: 'Failed to fetch usage statistics' });
    }
});

// Criar checkout session do Stripe
app.post('/api/checkout', createRateLimit('checkout'), async (req, res) => {
    try {
        const { orgId } = req;
        const { plan_id, billing_cycle = 'monthly' } = req.body;

        if (!plan_id) {
            return res.status(400).json({ error: 'Plan ID is required' });
        }

        // Obter informações do plano
        const planResult = await masterDb.query(`
            SELECT * FROM plans WHERE id = $1 AND is_active = true
        `, [plan_id]);

        if (planResult.rows.length === 0) {
            return res.status(404).json({ error: 'Plan not found' });
        }

        const plan = planResult.rows[0];
        const priceId = billing_cycle === 'yearly' 
            ? plan.stripe_price_id_yearly 
            : plan.stripe_price_id_monthly;

        if (!priceId) {
            return res.status(400).json({ error: 'Price ID not configured for this plan' });
        }

        // Obter dados da organização
        const orgResult = await masterDb.query(`
            SELECT name, created_by FROM organizations WHERE id = $1
        `, [orgId]);

        if (orgResult.rows.length === 0) {
            return res.status(404).json({ error: 'Organization not found' });
        }

        const organization = orgResult.rows[0];

        // Criar checkout session
        const session = await stripe.checkout.sessions.create({
            payment_method_types: ['card'],
            line_items: [{
                price: priceId,
                quantity: 1,
            }],
            mode: 'subscription',
            success_url: `${req.headers.origin || 'http://localhost:3000'}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
            cancel_url: `${req.headers.origin || 'http://localhost:3000'}/billing/plans`,
            client_reference_id: orgId.toString(),
            customer_email: req.body.email,
            metadata: {
                organization_id: orgId.toString(),
                organization_name: organization.name,
                plan_id: plan_id.toString(),
                billing_cycle: billing_cycle
            }
        });

        res.json({
            success: true,
            checkout_url: session.url,
            session_id: session.id
        });
    } catch (error) {
        console.error('Error creating checkout session:', error);
        res.status(500).json({ error: 'Failed to create checkout session' });
    }
});

// Portal de gerenciamento de assinatura
app.post('/api/customer-portal', createRateLimit('portal'), async (req, res) => {
    try {
        const { orgId } = req;

        // Obter customer_id do Stripe
        const result = await masterDb.query(`
            SELECT stripe_customer_id FROM subscriptions 
            WHERE organization_id = $1 AND status = 'active'
        `, [orgId]);

        if (result.rows.length === 0 || !result.rows[0].stripe_customer_id) {
            return res.status(404).json({ error: 'No active subscription found' });
        }

        const session = await stripe.billingPortal.sessions.create({
            customer: result.rows[0].stripe_customer_id,
            return_url: `${req.headers.origin || 'http://localhost:3000'}/billing`,
        });

        res.json({
            success: true,
            portal_url: session.url
        });
    } catch (error) {
        console.error('Error creating customer portal:', error);
        res.status(500).json({ error: 'Failed to create customer portal' });
    }
});

// Webhook do Stripe
app.post('/webhook/stripe', express.raw({ type: 'application/json' }), async (req, res) => {
    const sig = req.headers['stripe-signature'];
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

    try {
        const event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);

        console.log(`Stripe webhook: ${event.type}`);

        switch (event.type) {
            case 'checkout.session.completed':
                await handleCheckoutCompleted(event.data.object);
                break;
            
            case 'invoice.payment_succeeded':
                await handlePaymentSucceeded(event.data.object);
                break;
            
            case 'invoice.payment_failed':
                await handlePaymentFailed(event.data.object);
                break;
            
            case 'customer.subscription.updated':
                await handleSubscriptionUpdated(event.data.object);
                break;
            
            case 'customer.subscription.deleted':
                await handleSubscriptionCancelled(event.data.object);
                break;
        }

        res.json({ received: true });
    } catch (error) {
        console.error('Stripe webhook error:', error);
        res.status(400).json({ error: 'Webhook signature verification failed' });
    }
});

// Handlers para webhooks do Stripe
async function handleCheckoutCompleted(session) {
    const orgId = parseInt(session.client_reference_id);
    const planId = parseInt(session.metadata.plan_id);
    const billingCycle = session.metadata.billing_cycle;

    // Obter subscription do Stripe
    const subscription = await stripe.subscriptions.retrieve(session.subscription);

    await masterDb.query(`
        INSERT INTO subscriptions 
        (organization_id, plan_id, status, billing_cycle, current_period_start, current_period_end, stripe_customer_id, stripe_subscription_id)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (organization_id) DO UPDATE SET
            plan_id = EXCLUDED.plan_id,
            status = EXCLUDED.status,
            billing_cycle = EXCLUDED.billing_cycle,
            current_period_start = EXCLUDED.current_period_start,
            current_period_end = EXCLUDED.current_period_end,
            stripe_customer_id = EXCLUDED.stripe_customer_id,
            stripe_subscription_id = EXCLUDED.stripe_subscription_id,
            updated_at = NOW()
    `, [
        orgId,
        planId,
        subscription.status,
        billingCycle,
        new Date(subscription.current_period_start * 1000),
        new Date(subscription.current_period_end * 1000),
        subscription.customer,
        subscription.id
    ]);

    console.log(`Subscription created for org ${orgId}`);
}

async function handlePaymentSucceeded(invoice) {
    const subscription = await stripe.subscriptions.retrieve(invoice.subscription);
    
    await masterDb.query(`
        INSERT INTO invoices 
        (organization_id, subscription_id, stripe_invoice_id, amount_total, amount_paid, status, invoice_url, period_start, period_end, paid_at)
        SELECT s.organization_id, s.id, $1, $2, $3, $4, $5, $6, $7, $8
        FROM subscriptions s 
        WHERE s.stripe_subscription_id = $9
    `, [
        invoice.id,
        invoice.amount_paid / 100, // Stripe usa centavos
        invoice.amount_paid / 100,
        'paid',
        invoice.hosted_invoice_url,
        new Date(invoice.period_start * 1000),
        new Date(invoice.period_end * 1000),
        new Date(invoice.status_transitions.paid_at * 1000),
        subscription.id
    ]);

    console.log(`Payment succeeded for invoice ${invoice.id}`);
}

async function handlePaymentFailed(invoice) {
    await masterDb.query(`
        UPDATE subscriptions 
        SET status = 'past_due', updated_at = NOW()
        WHERE stripe_subscription_id = $1
    `, [invoice.subscription]);

    console.log(`Payment failed for subscription ${invoice.subscription}`);
}

async function handleSubscriptionUpdated(subscription) {
    await masterDb.query(`
        UPDATE subscriptions 
        SET 
            status = $1,
            current_period_start = $2,
            current_period_end = $3,
            cancel_at_period_end = $4,
            updated_at = NOW()
        WHERE stripe_subscription_id = $5
    `, [
        subscription.status,
        new Date(subscription.current_period_start * 1000),
        new Date(subscription.current_period_end * 1000),
        subscription.cancel_at_period_end,
        subscription.id
    ]);

    console.log(`Subscription updated: ${subscription.id}`);
}

async function handleSubscriptionCancelled(subscription) {
    await masterDb.query(`
        UPDATE subscriptions 
        SET status = 'canceled', updated_at = NOW()
        WHERE stripe_subscription_id = $1
    `, [subscription.id]);

    console.log(`Subscription cancelled: ${subscription.id}`);
}

// Middleware de tratamento de erros
app.use((error, req, res, next) => {
    console.error('API Error:', error);
    res.status(500).json({ 
        error: 'Internal server error',
        message: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
});

// Iniciar servidor
app.listen(PORT, () => {
    console.log(`🚀 Billing API rodando na porta ${PORT}`);
    console.log(`🔗 Health check: http://localhost:${PORT}/health`);
    console.log(`🏢 Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
    console.log('🛑 Shutting down billing API...');
    await masterDb.end();
    process.exit(0);
});

module.exports = app;