export function getResourceName(): string {
  const w = window as any
  if (typeof w.GetParentResourceName === 'function') return w.GetParentResourceName()
  // Fallback for local dev
  return 'qbx_taxijob'
}

export async function nuiSend<T = any>(event: string, data?: unknown): Promise<T | undefined> {
  const resourceName = getResourceName()
  try {
    const res = await fetch(`https://${resourceName}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data ?? {}),
    })
    try {
      return (await res.json()) as T
    } catch {
      return undefined
    }
  } catch {
    return undefined
  }
}
