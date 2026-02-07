import { useEffect, useRef } from 'react'

export function useNuiEvent<T>(action: string, handler: (data: T) => void) {
  const savedHandler = useRef(handler)

  useEffect(() => {
    savedHandler.current = handler
  }, [handler])

  useEffect(() => {
    const eventListener = (event: MessageEvent) => {
      const { data } = event
      if (data.action === action) {
        savedHandler.current(data)
      }
    }

    window.addEventListener('message', eventListener)
    return () => window.removeEventListener('message', eventListener)
  }, [action])
}
