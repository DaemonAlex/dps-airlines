import { useState, useEffect, useCallback } from 'react'
import { fetchCallback } from '../hooks/fetchNui'

interface Flight {
  id: number
  flight_number: string
  aircraft_model: string
  departure_airport: string
  arrival_airport: string
  passengers: number
  cargo_weight: number
  flight_type: string
  status: string
  distance: number
  duration: number
  fuel_used: number
  landing_quality: string | null
  total_pay: number
  departure_time: string
  arrival_time: string | null
}

const flightTypeBadge: Record<string, string> = {
  scheduled: 'badge-info',
  charter: 'badge-warning',
  priority: 'badge-danger',
  emergency: 'badge-danger',
  ferry: 'badge-default',
}

const statusBadge: Record<string, string> = {
  completed: 'badge-success',
  active: 'badge-info',
  failed: 'badge-danger',
  cancelled: 'badge-default',
}

export function FlightLog() {
  const [flights, setFlights] = useState<Flight[]>([])
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(1)
  const [sortField, setSortField] = useState<keyof Flight>('departure_time')
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc')

  const loadFlights = useCallback(() => {
    setLoading(true)
    fetchCallback<Flight[]>('getFlightLog', [page, 20])
      .then((data) => {
        setFlights(Array.isArray(data) ? data : [])
        setLoading(false)
      })
      .catch(() => setLoading(false))
  }, [page])

  useEffect(() => {
    loadFlights()
  }, [loadFlights])

  const handleSort = (field: keyof Flight) => {
    if (sortField === field) {
      setSortDir(sortDir === 'asc' ? 'desc' : 'asc')
    } else {
      setSortField(field)
      setSortDir('desc')
    }
  }

  const sortedFlights = [...flights].sort((a, b) => {
    const aVal = a[sortField]
    const bVal = b[sortField]
    if (aVal === null || aVal === undefined) return 1
    if (bVal === null || bVal === undefined) return -1
    if (aVal < bVal) return sortDir === 'asc' ? -1 : 1
    if (aVal > bVal) return sortDir === 'asc' ? 1 : -1
    return 0
  })

  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}m ${secs}s`
  }

  if (loading) {
    return (
      <div className="loading">
        <div className="loading-spinner" />
        Loading flight log...
      </div>
    )
  }

  if (flights.length === 0) {
    return (
      <div className="empty-state">
        <div className="empty-state-icon">&#9992;</div>
        <p>No flights recorded yet</p>
      </div>
    )
  }

  return (
    <div>
      <h2 className="section-header">Flight Log</h2>

      <div className="card" style={{ overflowX: 'auto' }}>
        <table className="data-table">
          <thead>
            <tr>
              <th onClick={() => handleSort('flight_number')} style={{ cursor: 'pointer' }}>
                Flight # {sortField === 'flight_number' && (sortDir === 'asc' ? '↑' : '↓')}
              </th>
              <th>Route</th>
              <th>Aircraft</th>
              <th onClick={() => handleSort('flight_type')} style={{ cursor: 'pointer' }}>
                Type {sortField === 'flight_type' && (sortDir === 'asc' ? '↑' : '↓')}
              </th>
              <th onClick={() => handleSort('status')} style={{ cursor: 'pointer' }}>
                Status {sortField === 'status' && (sortDir === 'asc' ? '↑' : '↓')}
              </th>
              <th>Pax</th>
              <th>Cargo</th>
              <th>Duration</th>
              <th>Landing</th>
              <th onClick={() => handleSort('total_pay')} style={{ cursor: 'pointer' }}>
                Pay {sortField === 'total_pay' && (sortDir === 'asc' ? '↑' : '↓')}
              </th>
              <th onClick={() => handleSort('departure_time')} style={{ cursor: 'pointer' }}>
                Date {sortField === 'departure_time' && (sortDir === 'asc' ? '↑' : '↓')}
              </th>
            </tr>
          </thead>
          <tbody>
            {sortedFlights.map((flight) => (
              <tr key={flight.id}>
                <td style={{ fontWeight: 600 }}>{flight.flight_number}</td>
                <td>{flight.departure_airport} → {flight.arrival_airport}</td>
                <td>{flight.aircraft_model}</td>
                <td>
                  <span className={`badge ${flightTypeBadge[flight.flight_type] || 'badge-default'}`}>
                    {flight.flight_type}
                  </span>
                </td>
                <td>
                  <span className={`badge ${statusBadge[flight.status] || 'badge-default'}`}>
                    {flight.status}
                  </span>
                </td>
                <td>{flight.passengers}</td>
                <td>{flight.cargo_weight}kg</td>
                <td>{flight.duration ? formatDuration(flight.duration) : '-'}</td>
                <td>
                  {flight.landing_quality ? (
                    <span className={`badge ${
                      flight.landing_quality === 'Butter' ? 'badge-success' :
                      flight.landing_quality === 'Normal' ? 'badge-info' :
                      flight.landing_quality === 'Hard' ? 'badge-warning' : 'badge-danger'
                    }`}>
                      {flight.landing_quality}
                    </span>
                  ) : '-'}
                </td>
                <td style={{ color: '#4ecca3', fontWeight: 600 }}>${flight.total_pay.toLocaleString()}</td>
                <td style={{ fontSize: 12, color: '#667788' }}>
                  {new Date(flight.departure_time).toLocaleDateString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="pagination">
        <button
          className={`page-btn ${page <= 1 ? '' : ''}`}
          onClick={() => setPage(Math.max(1, page - 1))}
          disabled={page <= 1}
        >
          Previous
        </button>
        <button className="page-btn active">Page {page}</button>
        <button
          className="page-btn"
          onClick={() => setPage(page + 1)}
          disabled={flights.length < 20}
        >
          Next
        </button>
      </div>
    </div>
  )
}
