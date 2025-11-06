import React from 'react'
import { cn } from '@/lib/utils'

type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'default' | 'destructive' | 'outline'
}

export const buttonVariants = {
  default: 'bg-sky-500 text-white hover:bg-sky-600',
  destructive: 'bg-red-500 text-white hover:bg-red-600',
  outline: 'border border-gray-300 text-gray-800 bg-transparent',
}

export const Button: React.FC<ButtonProps> = ({ className, variant = 'default', children, ...props }) => {
  return (
    <button
      className={cn('inline-flex items-center justify-center rounded-md px-4 py-2 text-sm font-semibold transition-colors',
        buttonVariants[variant],
        className)}
      {...props}
    >
      {children}
    </button>
  )
}

export default Button
