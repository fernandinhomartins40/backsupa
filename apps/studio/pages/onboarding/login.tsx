/**
 * Página de login para onboarding multi-tenant
 * Usa o design system existente do Supabase
 */

import { useState } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'
import Head from 'next/head'
import { Eye, EyeOff, Loader2 } from 'lucide-react'
import { Button, Input, cn } from 'ui'
import { controlApiAuth } from 'lib/api/controlApi'

export default function LoginPage() {
  const router = useRouter()
  const [isLoading, setIsLoading] = useState(false)
  const [showPassword, setShowPassword] = useState(false)
  const [formData, setFormData] = useState({
    email: '',
    password: '',
  })
  const [errors, setErrors] = useState<Record<string, string>>({})

  const validateForm = () => {
    const newErrors: Record<string, string> = {}

    if (!formData.email.trim()) {
      newErrors.email = 'Email é obrigatório'
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      newErrors.email = 'Email inválido'
    }

    if (!formData.password) {
      newErrors.password = 'Senha é obrigatória'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!validateForm()) return

    setIsLoading(true)

    try {
      const success = await controlApiAuth.login(formData.email, formData.password)
      
      if (success) {
        // Redirecionar para seleção de organização se não tiver, senão para projetos
        router.push('/onboarding/organization')
      } else {
        setErrors({ submit: 'Credenciais inválidas' })
      }
    } catch (error: any) {
      console.error('Login error:', error)
      setErrors({ submit: error.message || 'Erro ao fazer login. Tente novamente.' })
    } finally {
      setIsLoading(false)
    }
  }

  const handleInputChange = (field: string, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }))
    // Limpar erro do campo quando usuário digita
    if (errors[field]) {
      setErrors(prev => ({ ...prev, [field]: '' }))
    }
  }

  return (
    <>
      <Head>
        <title>Login | Supabase</title>
        <meta name="description" content="Faça login na sua conta Supabase" />
      </Head>

      <div className="min-h-screen bg-background flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-md w-full space-y-8">
          {/* Header */}
          <div className="text-center">
            <img
              src="/supabase-logo.svg"
              alt="Supabase"
              className="mx-auto h-12 w-auto"
            />
            <h2 className="mt-6 text-3xl font-bold text-foreground">
              Bem-vindo de volta
            </h2>
            <p className="mt-2 text-sm text-foreground-light">
              Faça login na sua conta
            </p>
          </div>

          {/* Form */}
          <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
            <div className="space-y-4">
              {/* Email */}
              <div>
                <label htmlFor="email" className="sr-only">
                  Email
                </label>
                <Input
                  id="email"
                  type="email"
                  placeholder="Email"
                  value={formData.email}
                  onChange={(e) => handleInputChange('email', e.target.value)}
                  disabled={isLoading}
                  error={errors.email}
                  className={cn(errors.email && 'border-red-500')}
                />
                {errors.email && (
                  <p className="mt-1 text-xs text-red-600">{errors.email}</p>
                )}
              </div>

              {/* Senha */}
              <div>
                <label htmlFor="password" className="sr-only">
                  Senha
                </label>
                <div className="relative">
                  <Input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    placeholder="Senha"
                    value={formData.password}
                    onChange={(e) => handleInputChange('password', e.target.value)}
                    disabled={isLoading}
                    error={errors.password}
                    className={cn(errors.password && 'border-red-500')}
                  />
                  <button
                    type="button"
                    className="absolute inset-y-0 right-0 pr-3 flex items-center"
                    onClick={() => setShowPassword(!showPassword)}
                  >
                    {showPassword ? (
                      <EyeOff className="h-4 w-4 text-foreground-light" />
                    ) : (
                      <Eye className="h-4 w-4 text-foreground-light" />
                    )}
                  </button>
                </div>
                {errors.password && (
                  <p className="mt-1 text-xs text-red-600">{errors.password}</p>
                )}
              </div>
            </div>

            {/* Esqueci senha link */}
            <div className="flex items-center justify-end">
              <Link
                href="/forgot-password"
                className="text-sm text-brand hover:text-brand-600"
              >
                Esqueceu a senha?
              </Link>
            </div>

            {/* Erro geral */}
            {errors.submit && (
              <div className="text-center">
                <p className="text-sm text-red-600">{errors.submit}</p>
              </div>
            )}

            {/* Submit button */}
            <div>
              <Button
                type="submit"
                className="w-full"
                disabled={isLoading}
                loading={isLoading}
              >
                {isLoading ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                    Entrando...
                  </>
                ) : (
                  'Entrar'
                )}
              </Button>
            </div>

            {/* Signup link */}
            <div className="text-center">
              <p className="text-sm text-foreground-light">
                Não tem uma conta?{' '}
                <Link
                  href="/onboarding/signup"
                  className="font-medium text-brand hover:text-brand-600"
                >
                  Criar conta gratuita
                </Link>
              </p>
            </div>
          </form>

          {/* Demo credentials */}
          <div className="mt-6 p-4 bg-surface-100 rounded-lg border border-border">
            <h4 className="text-sm font-medium text-foreground mb-2">
              Credenciais de demonstração:
            </h4>
            <div className="text-xs text-foreground-light space-y-1">
              <p><strong>Email:</strong> admin@localhost</p>
              <p><strong>Senha:</strong> admin123</p>
            </div>
            <Button
              type="button"
              size="tiny"
              variant="outline"
              className="mt-2 w-full"
              onClick={() => {
                setFormData({
                  email: 'admin@localhost',
                  password: 'admin123'
                })
              }}
            >
              Usar credenciais demo
            </Button>
          </div>
        </div>
      </div>
    </>
  )
}