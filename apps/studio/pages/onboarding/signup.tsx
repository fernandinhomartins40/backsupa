/**
 * Página de registro para onboarding multi-tenant
 * Usa o design system existente do Supabase
 */

import { useState } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'
import Head from 'next/head'
import { Eye, EyeOff, Loader2 } from 'lucide-react'
import { Button, Input, cn } from 'ui'
import { controlApiAuth } from 'lib/api/controlApi'

export default function SignUpPage() {
  const router = useRouter()
  const [isLoading, setIsLoading] = useState(false)
  const [showPassword, setShowPassword] = useState(false)
  const [formData, setFormData] = useState({
    firstName: '',
    lastName: '',
    email: '',
    password: '',
    confirmPassword: '',
  })
  const [errors, setErrors] = useState<Record<string, string>>({})

  const validateForm = () => {
    const newErrors: Record<string, string> = {}

    if (!formData.firstName.trim()) {
      newErrors.firstName = 'Nome é obrigatório'
    }

    if (!formData.lastName.trim()) {
      newErrors.lastName = 'Sobrenome é obrigatório'
    }

    if (!formData.email.trim()) {
      newErrors.email = 'Email é obrigatório'
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      newErrors.email = 'Email inválido'
    }

    if (!formData.password) {
      newErrors.password = 'Senha é obrigatória'
    } else if (formData.password.length < 8) {
      newErrors.password = 'Senha deve ter pelo menos 8 caracteres'
    }

    if (formData.password !== formData.confirmPassword) {
      newErrors.confirmPassword = 'Senhas não coincidem'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!validateForm()) return

    setIsLoading(true)

    try {
      // Simular registro (implementar com API real)
      await new Promise(resolve => setTimeout(resolve, 1500))
      
      // Por enquanto, fazer login após registro bem-sucedido
      const success = await controlApiAuth.login(formData.email, formData.password)
      
      if (success) {
        router.push('/onboarding/organization')
      } else {
        setErrors({ submit: 'Erro ao fazer login após registro' })
      }
    } catch (error) {
      console.error('Registration error:', error)
      setErrors({ submit: 'Erro ao criar conta. Tente novamente.' })
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
        <title>Criar conta | Supabase</title>
        <meta name="description" content="Crie sua conta no Supabase" />
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
              Criar conta
            </h2>
            <p className="mt-2 text-sm text-foreground-light">
              Comece a construir em segundos
            </p>
          </div>

          {/* Form */}
          <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
            <div className="space-y-4">
              {/* Nome */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label htmlFor="firstName" className="sr-only">
                    Nome
                  </label>
                  <Input
                    id="firstName"
                    type="text"
                    placeholder="Nome"
                    value={formData.firstName}
                    onChange={(e) => handleInputChange('firstName', e.target.value)}
                    disabled={isLoading}
                    error={errors.firstName}
                    className={cn(errors.firstName && 'border-red-500')}
                  />
                  {errors.firstName && (
                    <p className="mt-1 text-xs text-red-600">{errors.firstName}</p>
                  )}
                </div>

                <div>
                  <label htmlFor="lastName" className="sr-only">
                    Sobrenome
                  </label>
                  <Input
                    id="lastName"
                    type="text"
                    placeholder="Sobrenome"
                    value={formData.lastName}
                    onChange={(e) => handleInputChange('lastName', e.target.value)}
                    disabled={isLoading}
                    error={errors.lastName}
                    className={cn(errors.lastName && 'border-red-500')}
                  />
                  {errors.lastName && (
                    <p className="mt-1 text-xs text-red-600">{errors.lastName}</p>
                  )}
                </div>
              </div>

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

              {/* Confirmar senha */}
              <div>
                <label htmlFor="confirmPassword" className="sr-only">
                  Confirmar senha
                </label>
                <Input
                  id="confirmPassword"
                  type="password"
                  placeholder="Confirmar senha"
                  value={formData.confirmPassword}
                  onChange={(e) => handleInputChange('confirmPassword', e.target.value)}
                  disabled={isLoading}
                  error={errors.confirmPassword}
                  className={cn(errors.confirmPassword && 'border-red-500')}
                />
                {errors.confirmPassword && (
                  <p className="mt-1 text-xs text-red-600">{errors.confirmPassword}</p>
                )}
              </div>
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
                    Criando conta...
                  </>
                ) : (
                  'Criar conta'
                )}
              </Button>
            </div>

            {/* Login link */}
            <div className="text-center">
              <p className="text-sm text-foreground-light">
                Já tem uma conta?{' '}
                <Link
                  href="/onboarding/login"
                  className="font-medium text-brand hover:text-brand-600"
                >
                  Fazer login
                </Link>
              </p>
            </div>
          </form>

          {/* Terms */}
          <div className="text-center">
            <p className="text-xs text-foreground-lighter">
              Ao criar uma conta, você concorda com nossos{' '}
              <a href="#" className="underline hover:text-foreground">
                Termos de Serviço
              </a>{' '}
              e{' '}
              <a href="#" className="underline hover:text-foreground">
                Política de Privacidade
              </a>
            </p>
          </div>
        </div>
      </div>
    </>
  )
}