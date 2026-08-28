import { useState, useEffect } from 'react'
import { fetchCallback } from '../hooks/fetchNui'

interface TypeRating {
  model: string
  granted: number
}

interface FleetPlane { model: string; label: string; class: string; minRank?: number }

const classLabels: Record<string, string> = {
  prop: 'Propeller',
  small: 'Small Jet',
  medium: 'Medium Jet',
  large: 'Large Aircraft',
  cargo: 'Cargo Aircraft',
  helicopter: 'Helicopter',
}

export function TypeRatings() {
  const [ratings, setRatings] = useState<Record<string, TypeRating>>({})
  const [allAircraft, setAllAircraft] = useState<FleetPlane[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<string>('all')

  useEffect(() => {
    fetchCallback<{ ratings: Record<string, TypeRating>; fleet: FleetPlane[] }>('getTypeRatings')
      .then((data) => {
        setRatings(data && data.ratings ? data.ratings : {})
        setAllAircraft(data && Array.isArray(data.fleet) ? data.fleet : [])
        setLoading(false)
      })
      .catch(() => setLoading(false))
  }, [])

  if (loading) {
    return (
      <div className="loading">
        <div className="loading-spinner" />
        Loading type ratings...
      </div>
    )
  }

  const classes = ['all', ...new Set(allAircraft.map((a) => a.class))]

  const filteredAircraft = filter === 'all'
    ? allAircraft
    : allAircraft.filter((a) => a.class === filter)

  const unlockedCount = allAircraft.filter((a) => ratings[a.model]).length

  return (
    <div>
      <h2 className="section-header">
        Type Ratings ({unlockedCount}/{allAircraft.length} unlocked)
      </h2>

      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {classes.map((cls) => (
          <button
            key={cls}
            className={`page-btn ${filter === cls ? 'active' : ''}`}
            onClick={() => setFilter(cls)}
          >
            {cls === 'all' ? 'All' : classLabels[cls] || cls}
          </button>
        ))}
      </div>

      <div className="aircraft-grid">
        {filteredAircraft.map((aircraft) => {
          const isUnlocked = !!ratings[aircraft.model]
          return (
            <div key={aircraft.model} className={`aircraft-card ${isUnlocked ? 'unlocked' : 'locked'}`}>
              <div style={{ fontSize: 32, marginBottom: 8 }}
                dangerouslySetInnerHTML={{ __html: aircraft.class === 'helicopter' ? '&#128641;' : '&#9992;' }} />
              <div className="aircraft-name">{aircraft.label}</div>
              <div className="aircraft-class">{classLabels[aircraft.class] || aircraft.class}</div>
              <div style={{ marginTop: 8 }}>
                {isUnlocked ? (
                  <span className="badge badge-success">Certified</span>
                ) : (
                  <span className="badge badge-default">Locked</span>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
