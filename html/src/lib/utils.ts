// Minimal `cn` helper used by shadcn-style components.
export function cn(...inputs: Array<string | false | null | undefined>) {
  return inputs.filter(Boolean).join(' ')
}
