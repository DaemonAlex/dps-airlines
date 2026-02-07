import { useState, useEffect } from 'react'
import { fetchCallback } from '../hooks/fetchNui'

interface PilotStats {
  total_flights: number
  successful_flights: number
  failed_flights: number
  total_passengers: number
  total_cargo: number
  total_distance: number
  total_earnings: number
  flight_hours: number
  copilot_hours: number
  attendant_flights: number
  ground_tasks_completed: number
  dispatches_created: number
  service_rating: number
  landing_rating: number
  incidents: number
  reputation: number
  role: string
  licenses: string | null
}

interface CompanyStats {
  totalFlights: number
  totalEmployees: number
  totalEarnings: number
  averageRating: number
  activeContracts: number
  balance: number
}

interface OverviewProps {
  data: Record<string, unknown>
}

const roleLabels: Record<string, string> = {
  ground_crew: 'Ground Crew',
  flight_attendant: 'Flight Attendant',
  dispatcher: 'Dispatcher',
  first_officer: 'First Officer',
  captain: 'Captain',
  chief_pilot: 'Chief Pilot',
}

export function Overview({ data: _data }: OverviewProps) {
  const [stats, setStats] = useState<PilotStats | null>(null)
  const [companyStats, setCompanyStats] = useState<CompanyStats | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    Promise.all([
      fetchCallback<PilotStats>('getPilotStats'),
      fetchCallback<CompanyStats>('getCompanyStats'),
    ]).then(([pilotData, companyData]) => {
      setStats(pilotData)
      setCompanyStats(companyData)
      setLoading(false)
    }).catch(() => setLoading(false))
  }, [])

  if (loading) {
    return (
      <div className="loading">
        <div className="loading-spinner" />
        Loading statistics...
      </div>
    )
  }

  return (
    <div>
      <h2 className="section-header">Pilot Overview</h2>

      {stats && (
        <>
          <div style={{ marginBottom: 16, display: 'flex', gap: 12, alignItems: 'center' }}>
            <span className="badge badge-info">{roleLabels[stats.role] || stats.role}</span>
            <span className="badge badge-success">Rep: {stats.reputation}</span>
            {stats.licenses && <span className="badge badge-warning">Licensed</span>}
          </div>

          <div className="stat-grid">
            <div className="stat-card">
              <div className="stat-label">Total Flights</div>
              <div className="stat-number">{stats.total_flights}</div>
              <div className="stat-sub">{stats.successful_flights} successful</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Flight Hours</div>
              <div className="stat-number">{stats.flight_hours.toFixed(1)}</div>
              <div className="stat-sub">{stats.copilot_hours.toFixed(1)}h as co-pilot</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Total Earnings</div>
              <div className="stat-number">${stats.total_earnings.toLocaleString()}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Passengers Carried</div>
              <div className="stat-number">{stats.total_passengers.toLocaleString()}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Cargo Hauled</div>
              <div className="stat-number">{(stats.total_cargo / 1000).toFixed(1)}t</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Distance Flown</div>
              <div className="stat-number">{(stats.total_distance / 1000).toFixed(0)}km</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Service Rating</div>
              <div className="stat-number">{stats.service_rating.toFixed(1)}</div>
              <div className="stat-sub">out of 5.0</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Landing Rating</div>
              <div className="stat-number">{stats.landing_rating.toFixed(1)}</div>
              <div className="stat-sub">out of 5.0</div>
            </div>
          </div>

          <h2 className="section-header">Role Statistics</h2>
          <div className="stat-grid">
            <div className="stat-card">
              <div className="stat-label">Ground Tasks</div>
              <div className="stat-number">{stats.ground_tasks_completed}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Attendant Flights</div>
              <div className="stat-number">{stats.attendant_flights}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Dispatches Created</div>
              <div className="stat-number">{stats.dispatches_created}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Incidents</div>
              <div className="stat-number">{stats.incidents}</div>
            </div>
          </div>
        </>
      )}

      {companyStats && (
        <>
          <h2 className="section-header">Company Overview</h2>
          <div className="stat-grid">
            <div className="stat-card">
              <div className="stat-label">Company Flights</div>
              <div className="stat-number">{companyStats.totalFlights}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Employees</div>
              <div className="stat-number">{companyStats.totalEmployees}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Total Revenue</div>
              <div className="stat-number">${companyStats.totalEarnings.toLocaleString()}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Avg Rating</div>
              <div className="stat-number">{companyStats.averageRating}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Active Contracts</div>
              <div className="stat-number">{companyStats.activeContracts}</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Company Balance</div>
              <div className="stat-number">${companyStats.balance.toLocaleString()}</div>
            </div>
          </div>
        </>
      )}
    </div>
  )
}
