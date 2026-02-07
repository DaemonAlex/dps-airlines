import { useState, useEffect } from 'react'
import { fetchCallback } from '../hooks/fetchNui'

interface TypeRating {
  model: string
  granted: number
}

const allAircraft = [
  { model: 'luxor', label: 'Luxor', class: 'small', icon: '&#9992;' },
  { model: 'luxor2', label: 'Luxor Deluxe', class: 'small', icon: '&#9992;' },
  { model: 'shamal', label: 'Shamal', class: 'small', icon: '&#9992;' },
  { model: 'miljet', label: 'Miljet', class: 'medium', icon: '&#9992;' },
  { model: 'nimbus', label: 'Nimbus', class: 'medium', icon: '&#9992;' },
  { model: 'vestra', label: 'Vestra', class: 'small', icon: '&#9992;' },
  { model: 'velum', label: 'Velum', class: 'prop', icon: '&#9992;' },
  { model: 'velum2', label: 'Velum 5-Seater', class: 'prop', icon: '&#9992;' },
  { model: 'dodo', label: 'Dodo', class: 'prop', icon: '&#9992;' },
  { model: 'cuban800', label: 'Cuban 800', class: 'prop', icon: '&#9992;' },
  { model: 'mammatus', label: 'Mammatus', class: 'prop', icon: '&#9992;' },
  { model: 'duster', label: 'Duster', class: 'prop', icon: '&#9992;' },
  { model: 'stunt', label: 'Mallard', class: 'prop', icon: '&#9992;' },
  { model: 'titan', label: 'Titan', class: 'large', icon: '&#9992;' },
  { model: 'cargoplane', label: 'Cargo Plane', class: 'cargo', icon: '&#9992;' },
  { model: 'jet', label: 'Commercial Jet', class: 'large', icon: '&#9992;' },
  { model: 'alkonost', label: 'Alkonost', class: 'cargo', icon: '&#9992;' },
  { model: 'maverick', label: 'Maverick', class: 'helicopter', icon: '&#128641;' },
  { model: 'frogger', label: 'Frogger', class: 'helicopter', icon: '&#128641;' },
  { model: 'swift', label: 'Swift', class: 'helicopter', icon: '&#128641;' },
  { model: 'supervolito', label: 'SuperVolito', class: 'helicopter', icon: '&#128641;' },
]

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
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<string>('all')

  useEffect(() => {
    fetchCallback<Record<string, TypeRating>>('getTypeRatings')
      .then((data) => {
        setRatings(data && typeof data === 'object' ? data : {})
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
                dangerouslySetInnerHTML={{ __html: aircraft.icon }} />
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
