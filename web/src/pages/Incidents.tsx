import { useState, useEffect, useCallback } from 'react'
import { fetchCallback } from '../hooks/fetchNui'

interface Incident {
  id: number
  flight_id: number | null
  incident_type: string
  severity: string
  description: string | null
  resolved: boolean
  created_at: string
}

const severityBadge: Record<string, string> = {
  minor: 'badge-info',
  moderate: 'badge-warning',
  major: 'badge-danger',
  critical: 'badge-danger',
}

export function Incidents() {
  const [incidents, setIncidents] = useState<Incident[]>([])
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(1)

  const loadIncidents = useCallback(() => {
    setLoading(true)
    fetchCallback<Incident[]>('getIncidents', [page, 20])
      .then((data) => {
        setIncidents(Array.isArray(data) ? data : [])
        setLoading(false)
      })
      .catch(() => setLoading(false))
  }, [page])

  useEffect(() => {
    loadIncidents()
  }, [loadIncidents])

  if (loading) {
    return (
      <div className="loading">
        <div className="loading-spinner" />
        Loading incidents...
      </div>
    )
  }

  const safetyScore = incidents.length === 0 ? 100 :
    Math.max(0, 100 - incidents.filter((i) => !i.resolved).length * 10)

  return (
    <div>
      <h2 className="section-header">Safety Record</h2>

      <div className="stat-grid" style={{ marginBottom: 20 }}>
        <div className="stat-card">
          <div className="stat-label">Safety Score</div>
          <div className="stat-number" style={{
            color: safetyScore >= 80 ? '#4ecca3' : safetyScore >= 50 ? '#ffc107' : '#e94560'
          }}>
            {safetyScore}%
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Total Incidents</div>
          <div className="stat-number">{incidents.length}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Unresolved</div>
          <div className="stat-number" style={{ color: '#e94560' }}>
            {incidents.filter((i) => !i.resolved).length}
          </div>
        </div>
      </div>

      {incidents.length === 0 ? (
        <div className="empty-state">
          <div className="empty-state-icon">&#9989;</div>
          <p>Clean safety record - no incidents!</p>
        </div>
      ) : (
        <>
          <h2 className="section-header">Incident History</h2>
          <div>
            {incidents.map((incident) => (
              <div key={incident.id} className="card" style={{
                borderLeft: `3px solid ${incident.severity === 'minor' ? '#3498db' :
                  incident.severity === 'moderate' ? '#ffc107' : '#e94560'}`
              }}>
                <div className="card-header">
                  <div>
                    <span style={{ fontWeight: 600, color: '#fff', marginRight: 8 }}>
                      {incident.incident_type.replace(/_/g, ' ').toUpperCase()}
                    </span>
                    <span className={`badge ${severityBadge[incident.severity] || 'badge-default'}`}>
                      {incident.severity}
                    </span>
                    {incident.resolved && (
                      <span className="badge badge-success" style={{ marginLeft: 8 }}>Resolved</span>
                    )}
                  </div>
                  <span style={{ fontSize: 12, color: '#667788' }}>
                    {new Date(incident.created_at).toLocaleDateString()}
                  </span>
                </div>
                {incident.description && (
                  <p style={{ fontSize: 13, color: '#aab' }}>{incident.description}</p>
                )}
                {incident.flight_id && (
                  <p style={{ fontSize: 11, color: '#667788', marginTop: 4 }}>
                    Flight ID: {incident.flight_id}
                  </p>
                )}
              </div>
            ))}
          </div>

          <div className="pagination">
            <button className="page-btn" onClick={() => setPage(Math.max(1, page - 1))} disabled={page <= 1}>
              Previous
            </button>
            <button className="page-btn active">Page {page}</button>
            <button className="page-btn" onClick={() => setPage(page + 1)} disabled={incidents.length < 20}>
              Next
            </button>
          </div>
        </>
      )}
    </div>
  )
}
