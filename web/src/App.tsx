import { useState, useEffect, useCallback } from 'react'
import { Overview } from './pages/Overview'
import { FlightLog } from './pages/FlightLog'
import { TypeRatings } from './pages/TypeRatings'
import { Incidents } from './pages/Incidents'
import { FlightTracker } from './pages/FlightTracker'
import { CrewManagement } from './pages/CrewManagement'
import { useNuiEvent } from './hooks/useNuiEvent'
import { fetchNui } from './hooks/fetchNui'

type Page = 'overview' | 'flightlog' | 'typeratings' | 'incidents' | 'tracker' | 'crew'

interface NuiMessage {
  action: string
  page?: Page
  data?: Record<string, unknown>
}

function App() {
  const [visible, setVisible] = useState(false)
  const [currentPage, setCurrentPage] = useState<Page>('overview')
  const [pageData, setPageData] = useState<Record<string, unknown>>({})
  const [fuelLevel, setFuelLevel] = useState(100)

  useNuiEvent<NuiMessage>('open', (data) => {
    setVisible(true)
    if (data.page) setCurrentPage(data.page)
    if (data.data) setPageData(data.data)
  })

  useNuiEvent<NuiMessage>('close', () => {
    setVisible(false)
  })

  useNuiEvent<NuiMessage>('update', (data) => {
    if (data.page) setCurrentPage(data.page)
    if (data.data) setPageData((prev) => ({ ...prev, ...data.data }))
  })

  useNuiEvent<{ data: { level: number; burnRate: number } }>('updateFuel', (data) => {
    setFuelLevel(data.data?.level ?? 100)
  })

  const handleClose = useCallback(() => {
    setVisible(false)
    fetchNui('close', {})
  }, [])

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && visible) {
        handleClose()
      }
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [visible, handleClose])

  if (!visible) return null

  const pages: Record<Page, string> = {
    overview: 'Overview',
    flightlog: 'Flight Log',
    typeratings: 'Type Ratings',
    incidents: 'Incidents',
    tracker: 'Flight Tracker',
    crew: 'Crew Management',
  }

  return (
    <div className="nui-wrapper">
      <div className="nui-container">
        <div className="nui-header">
          <div className="nui-logo">
            <span className="logo-icon">&#9992;</span>
            <span className="logo-text">DPS Airlines</span>
          </div>
          <nav className="nui-nav">
            {(Object.keys(pages) as Page[]).map((page) => (
              <button
                key={page}
                className={`nav-btn ${currentPage === page ? 'active' : ''}`}
                onClick={() => setCurrentPage(page)}
              >
                {pages[page]}
              </button>
            ))}
          </nav>
          <button className="close-btn" onClick={handleClose}>&#10005;</button>
        </div>

        <div className="nui-content">
          {currentPage === 'overview' && <Overview data={pageData} />}
          {currentPage === 'flightlog' && <FlightLog />}
          {currentPage === 'typeratings' && <TypeRatings />}
          {currentPage === 'incidents' && <Incidents />}
          {currentPage === 'tracker' && <FlightTracker />}
          {currentPage === 'crew' && <CrewManagement />}
        </div>

        {fuelLevel < 100 && (
          <div className="fuel-bar-wrapper">
            <div className="fuel-bar" style={{ width: `${fuelLevel}%` }}>
              <span>Fuel: {fuelLevel}%</span>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

export default App
