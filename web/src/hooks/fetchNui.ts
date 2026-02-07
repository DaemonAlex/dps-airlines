export async function fetchNui<T = unknown>(
  eventName: string,
  data?: Record<string, unknown>
): Promise<T> {
  const win = window as unknown as Record<string, unknown>
  const resourceName = win.GetParentResourceName
    ? (win.GetParentResourceName as () => string)()
    : 'dps-airlines'

  const resp = await fetch(`https://${resourceName}/${eventName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data ?? {}),
  })

  return resp.json() as Promise<T>
}

export async function fetchCallback<T = unknown>(
  callback: string,
  args: unknown[] = []
): Promise<T> {
  return fetchNui<T>('fetchData', { callback, args })
}
