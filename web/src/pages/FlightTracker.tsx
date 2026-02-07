import { useState, useEffect, useCallback } from 'react'
import { fetchCallback } from '../hooks/fetchNui'

interface TrackedFlight {
  flight_id: number
  citizenid: string
  pos_x: number
  pos_y: number
  pos_z: number
  heading: number
  speed: number
  altitude: number
  fuel_level: number
  phase: number
  flight_number: string
  departure_airport: string
  arrival_airport: string
  aircraft_model: string
}

const phaseNames: Record<number, string> = {
  0: 'Ground',
  1: 'Taxiing',
  2: 'Takeoff',
  3: 'Cruise',
  4: 'Approach',
  5: 'Landed',
}

const phaseBadge: Record<number, string> = {
  0: 'badge-default',
  1: 'badge-info',
  2: 'badge-warning',
  3: 'badge-success',
  4: 'badge-info',
  5: 'badge-success',
}

// Map bounds for GTA V (approximate)
const MAP_MIN_X = -4000
const MAP_MAX_X = 5000
const MAP_MIN_Y = -4500
const MAP_MAX_Y = 8500
const MAP_WIDTH = MAP_MAX_X - MAP_MIN_X
const MAP_HEIGHT = MAP_MAX_Y - MAP_MIN_Y

function mapToPercent(x: number, y: number) {
  return {
    left: ((x - MAP_MIN_X) / MAP_WIDTH) * 100,
    top: (1 - (y - MAP_MIN_Y) / MAP_HEIGHT) * 100,
  }
}

export function FlightTracker() {
  const [flights, setFlights] = useState<TrackedFlight[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedFlight, setSelectedFlight] = useState<TrackedFlight | null>(null)

  const loadFlights = useCallback(() => {
    fetchCallback<TrackedFlight[]>('getFlightTracker')
      .then((data) => {
        setFlights(Array.isArray(data) ? data : [])
        setLoading(false)
      })
      .catch(() => setLoading(false))
  }, [])

  useEffect(() => {
    loadFlights()
    const interval = setInterval(loadFlights, 5000) // Refresh every 5s
    return () => clearInterval(interval)
  }, [loadFlights])

  if (loading) {
    return (
      <div className="loading">
        <div className="loading-spinner" />
        Loading flight tracker...
      </div>
    )
  }

  return (
    <div>
      <h2 className="section-header">
        Live Flight Tracker ({flights.length} active)
      </h2>

      <div className="tracker-map">
        {flights.length === 0 ? (
          <span style={{ color: '#667788' }}>No active flights</span>
        ) : (
          flights.map((flight) => {
            const pos = mapToPercent(flight.pos_x, flight.pos_y)
            return (
              <div
                key={flight.flight_id}
                className="tracker-dot"
                style={{
                  left: `${Math.min(95, Math.max(5, pos.left))}%`,
                  top: `${Math.min(95, Math.max(5, pos.top))}%`,
                  cursor: 'pointer',
                  transform: `rotate(${flight.heading}deg)`,
                }}
                title={`${flight.flight_number} - ${flight.aircraft_model}`}
                onClick={() => setSelectedFlight(flight)}
              />
            )
          })
        )}
      </div>

      {selectedFlight && (
        <div className="card" style={{ marginTop: 12 }}>
          <div className="card-header">
            <div>
              <span style={{ fontWeight: 700, fontSize: 18, color: '#fff' }}>
                {selectedFlight.flight_number}
              </span>
              <span className={`badge ${phaseBadge[selectedFlight.phase] || 'badge-default'}`} style={{ marginLeft: 8 }}>
                {phaseNames[selectedFlight.phase] || 'Unknown'}
              </span>
            </div>
            <button
              className="page-btn"
              onClick={() => setSelectedFlight(null)}
            >
              Close
            </button>
          </div>
          <div className="stat-grid" style={{ marginBottom: 0 }}>
            <div className="stat-card">
              <div className="stat-label">Route</div>
              <div className="stat-number" style={{ fontSize: 16 }}>
                {selectedFlight.departure_airport} → {selectedFlight.arrival_airport}
              </div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Aircraft</div>
              <div className="stat-number" style={{ fontSize: 16 }}>
                {selectedFlight.aircraft_model}
              </div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Speed</div>
              <div className="stat-number">{Math.floor(selectedFlight.speed)}</div>
              <div className="stat-sub">knots</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Altitude</div>
              <div className="stat-number">{Math.floor(selectedFlight.altitude)}</div>
              <div className="stat-sub">ft</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Heading</div>
              <div className="stat-number">{Math.floor(selectedFlight.heading)}°</div>
            </div>
            <div className="stat-card">
              <div className="stat-label">Fuel</div>
              <div className="stat-number" style={{
                color: selectedFlight.fuel_level < 20 ? '#e94560' :
                  selectedFlight.fuel_level < 50 ? '#ffc107' : '#4ecca3'
              }}>
                {Math.floor(selectedFlight.fuel_level)}%
              </div>
            </div>
          </div>
        </div>
      )}

      {flights.length > 0 && (
        <>
          <h2 className="section-header" style={{ marginTop: 20 }}>Active Flights</h2>
          <div className="card" style={{ overflowX: 'auto' }}>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Flight</th>
                  <th>Route</th>
                  <th>Aircraft</th>
                  <th>Phase</th>
                  <th>Speed</th>
                  <th>Alt</th>
                  <th>Fuel</th>
                </tr>
              </thead>
              <tbody>
                {flights.map((f) => (
                  <tr key={f.flight_id} onClick={() => setSelectedFlight(f)} style={{ cursor: 'pointer' }}>
                    <td style={{ fontWeight: 600 }}>{f.flight_number}</td>
                    <td>{f.departure_airport} → {f.arrival_airport}</td>
                    <td>{f.aircraft_model}</td>
                    <td>
                      <span className={`badge ${phaseBadge[f.phase] || 'badge-default'}`}>
                        {phaseNames[f.phase]}
                      </span>
                    </td>
                    <td>{Math.floor(f.speed)} kts</td>
                    <td>{Math.floor(f.altitude)} ft</td>
                    <td style={{
                      color: f.fuel_level < 20 ? '#e94560' : f.fuel_level < 50 ? '#ffc107' : '#4ecca3'
                    }}>
                      {Math.floor(f.fuel_level)}%
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  )
}
