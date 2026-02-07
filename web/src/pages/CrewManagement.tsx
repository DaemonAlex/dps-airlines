import { useState, useEffect } from 'react'
import { fetchCallback } from '../hooks/fetchNui'

interface Employee {
  citizenid: string
  role: string
  assigned_role: string | null
  total_flights: number
  flight_hours: number
  total_earnings: number
  service_rating: number
  landing_rating: number
  ground_tasks_completed: number
  attendant_flights: number
  dispatches_created: number
  incidents: number
  reputation: number
}

const roleLabels: Record<string, string> = {
  ground_crew: 'Ground Crew',
  flight_attendant: 'Flight Attendant',
  dispatcher: 'Dispatcher',
  first_officer: 'First Officer',
  captain: 'Captain',
  chief_pilot: 'Chief Pilot',
}

const roleIcons: Record<string, string> = {
  ground_crew: '&#128736;',
  flight_attendant: '&#128116;',
  dispatcher: '&#128225;',
  first_officer: '&#9992;',
  captain: '&#9992;',
  chief_pilot: '&#11088;',
}

export function CrewManagement() {
  const [employees, setEmployees] = useState<Employee[]>([])
  const [loading, setLoading] = useState(true)
  const [filterRole, setFilterRole] = useState<string>('all')

  useEffect(() => {
    fetchCallback<Employee[]>('getEmployees')
      .then((data) => {
        setEmployees(Array.isArray(data) ? data : [])
        setLoading(false)
      })
      .catch(() => setLoading(false))
  }, [])

  if (loading) {
    return (
      <div className="loading">
        <div className="loading-spinner" />
        Loading employees...
      </div>
    )
  }

  if (employees.length === 0) {
    return (
      <div className="empty-state">
        <div className="empty-state-icon">&#128100;</div>
        <p>No employees found or insufficient permissions</p>
      </div>
    )
  }

  const roles = ['all', ...new Set(employees.map((e) => e.assigned_role || e.role))]
  const filtered = filterRole === 'all'
    ? employees
    : employees.filter((e) => (e.assigned_role || e.role) === filterRole)

  const totalHours = employees.reduce((sum, e) => sum + e.flight_hours, 0)
  const totalFlights = employees.reduce((sum, e) => sum + e.total_flights, 0)

  return (
    <div>
      <h2 className="section-header">Crew Roster ({employees.length} employees)</h2>

      <div className="stat-grid" style={{ marginBottom: 16 }}>
        <div className="stat-card">
          <div className="stat-label">Total Employees</div>
          <div className="stat-number">{employees.length}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Combined Hours</div>
          <div className="stat-number">{totalHours.toFixed(0)}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Combined Flights</div>
          <div className="stat-number">{totalFlights}</div>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {roles.map((role) => (
          <button
            key={role}
            className={`page-btn ${filterRole === role ? 'active' : ''}`}
            onClick={() => setFilterRole(role)}
          >
            {role === 'all' ? 'All' : roleLabels[role] || role}
          </button>
        ))}
      </div>

      <div className="crew-list">
        {filtered.map((emp) => {
          const role = emp.assigned_role || emp.role
          return (
            <div key={emp.citizenid} className="crew-card">
              <div className="crew-avatar"
                dangerouslySetInnerHTML={{ __html: roleIcons[role] || '&#128100;' }} />
              <div className="crew-info">
                <div className="crew-name">{emp.citizenid}</div>
                <div className="crew-role">{roleLabels[role] || role}</div>
                <div className="crew-stats">
                  {emp.flight_hours.toFixed(1)}h | {emp.total_flights} flights | Rating: {emp.service_rating.toFixed(1)} | Rep: {emp.reputation}
                </div>
                <div style={{ marginTop: 4, display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                  {emp.incidents > 0 && (
                    <span className="badge badge-warning">{emp.incidents} incidents</span>
                  )}
                  {emp.service_rating >= 4.5 && (
                    <span className="badge badge-success">Top Rated</span>
                  )}
                  {emp.flight_hours >= 100 && (
                    <span className="badge badge-info">Veteran</span>
                  )}
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
