import { useState, useEffect, useCallback } from 'react'
import { fetchCallback } from '../hooks/fetchNui'

interface TypeRating {
  model: string
  granted: number
}

// `covered`: the pilot license alone allows it. `fee`: type rating course price.
interface FleetPlane { model: string; label: string; class: string; minRank: number; covered: boolean; fee: number }

interface RatingsData {
  ratings: Record<string, TypeRating>
  fleet: FleetPlane[]
  hasLicense: boolean
  rank: number
  rankNames: Record<string, string>
}

interface BuyResult { ok: boolean; reason?: string; label?: string; fee?: number }

const classLabels: Record<string, string> = {
  prop: 'Propeller',
  small: 'Small Jet',
  medium: 'Medium Jet',
  large: 'Large Aircraft',
  cargo: 'Cargo Aircraft',
  helicopter: 'Helicopter',
}

const money = (n: number) => '$' + n.toLocaleString('en-US')

export function TypeRatings() {
  const [data, setData] = useState<RatingsData | null>(null)
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<string>('all')
  const [buying, setBuying] = useState<string | null>(null)
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null)

  const load = useCallback(() => {
    return fetchCallback<RatingsData>('getTypeRatings')
      .then((d) => {
        setData(d && Array.isArray(d.fleet) ? d : null)
        setLoading(false)
      })
      .catch(() => setLoading(false))
  }, [])

  useEffect(() => { load() }, [load])

  const buy = (plane: FleetPlane) => {
    setBuying(plane.model)
    setMessage(null)
    fetchCallback<BuyResult>('buyTypeRating', [plane.model])
      .then((r) => {
        if (r && r.ok) {
          setMessage({ ok: true, text: `Rated for the ${plane.label}` + (plane.fee > 0 ? ` (${money(plane.fee)})` : '') })
        } else {
          setMessage({ ok: false, text: (r && r.reason) || 'Could not get rated' })
        }
        return load()
      })
      .catch(() => setMessage({ ok: false, text: 'Could not get rated' }))
      .finally(() => setBuying(null))
  }

  if (loading) {
    return (
      <div className="loading">
        <div className="loading-spinner" />
        Loading type ratings...
      </div>
    )
  }

  if (!data) {
    return <div className="empty-state">Type ratings are unavailable right now.</div>
  }

  const { ratings, fleet, hasLicense, rank, rankNames } = data
  const classes = ['all', ...new Set(fleet.map((a) => a.class))]
  const filtered = filter === 'all' ? fleet : fleet.filter((a) => a.class === filter)

  // What a pilot may fly today: license-covered trainers plus rated aircraft, within rank.
  const canFly = (a: FleetPlane) => hasLicense && a.minRank <= rank && (a.covered || !!ratings[a.model])
  const flyable = fleet.filter(canFly).length

  return (
    <div>
      <h2 className="section-header">
        Type Ratings ({flyable}/{fleet.length} you can fly)
      </h2>

      {!hasLicense && (
        <div className="card" style={{ marginBottom: 16 }}>
          You need a pilot license before you can fly anything. Enroll at the flight school and pass the checkride;
          the license then covers the trainers, and the rest are rated here.
        </div>
      )}

      {message && (
        <div className="card" style={{ marginBottom: 16 }}>
          <span className={`badge ${message.ok ? 'badge-success' : 'badge-danger'}`}>{message.ok ? 'Done' : 'Not rated'}</span>
          <span style={{ marginLeft: 8 }}>{message.text}</span>
        </div>
      )}

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
        {filtered.map((aircraft) => {
          const rated = !!ratings[aircraft.model]
          const rankOk = aircraft.minRank <= rank
          return (
            <div key={aircraft.model} className={`aircraft-card ${canFly(aircraft) ? 'unlocked' : 'locked'}`}>
              <div style={{ fontSize: 32, marginBottom: 8 }}
                dangerouslySetInnerHTML={{ __html: aircraft.class === 'helicopter' ? '&#128641;' : '&#9992;' }} />
              <div className="aircraft-name">{aircraft.label}</div>
              <div className="aircraft-class">{classLabels[aircraft.class] || aircraft.class}</div>
              <div style={{ marginTop: 8 }}>
                {rated ? (
                  <span className="badge badge-success">Rated</span>
                ) : aircraft.covered ? (
                  <span className={`badge ${hasLicense ? 'badge-info' : 'badge-default'}`}>
                    {hasLicense ? 'Pilot license' : 'Needs license'}
                  </span>
                ) : !rankOk ? (
                  <span className="badge badge-default">Requires {rankNames[String(aircraft.minRank)] || `rank ${aircraft.minRank}`}</span>
                ) : !hasLicense ? (
                  <span className="badge badge-default">Needs license</span>
                ) : (
                  <button
                    className="page-btn active"
                    disabled={buying !== null}
                    onClick={() => buy(aircraft)}
                  >
                    {buying === aircraft.model ? 'Rating...' : `Get rated · ${money(aircraft.fee)}`}
                  </button>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
