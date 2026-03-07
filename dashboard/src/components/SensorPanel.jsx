import { useState } from 'react';

/* ── Helpers ─────────────────────────────────────────────────────── */

function timeAgo(ts) {
    if (!ts) return '—';
    const secs = Math.floor((Date.now() / 1000) - ts);
    if (secs < 10) return 'just now';
    if (secs < 60) return `${secs}s ago`;
    if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
    return `${Math.floor(secs / 3600)}h ago`;
}

function psiLevel(psi) {
    if (psi == null) return { label: '—', color: 'var(--text-tertiary)' };
    if (psi <= 50) return { label: 'Good', color: 'var(--green)' };
    if (psi <= 100) return { label: 'Moderate', color: 'var(--yellow)' };
    if (psi <= 200) return { label: 'Unhealthy', color: 'var(--orange)' };
    if (psi <= 300) return { label: 'Very Unhealthy', color: 'var(--red)' };
    return { label: 'Hazardous', color: '#8b0000' };
}

function rainfallLevel(mm) {
    if (mm <= 0) return { label: 'None', color: 'var(--text-tertiary)' };
    if (mm < 1) return { label: 'Light', color: 'var(--cyan)' };
    if (mm < 5) return { label: 'Moderate', color: 'var(--tint)' };
    if (mm < 20) return { label: 'Heavy', color: 'var(--orange)' };
    return { label: 'Intense', color: 'var(--red)' };
}

function weatherIcon(forecast) {
    const f = (forecast || '').toLowerCase();
    if (f.includes('thunder')) return '⛈';
    if (f.includes('heavy rain') || f.includes('heavy shower')) return '🌧';
    if (f.includes('rain') || f.includes('shower')) return '🌦';
    if (f.includes('cloudy')) return '☁️';
    if (f.includes('wind')) return '💨';
    if (f.includes('hazy')) return '🌫';
    if (f.includes('fair') || f.includes('sunny')) return '☀️';
    return '🌤';
}

/* ── Sub-components ──────────────────────────────────────────────── */

function SectionHeader({ icon, title, updatedTs, count }) {
    return (
        <div style={s.sectionHeader}>
            <span style={s.sectionIcon}>{icon}</span>
            <span style={s.sectionTitle}>{title}</span>
            {count != null && <span style={s.sectionCount}>{count}</span>}
            <span style={s.sectionTime}>{timeAgo(updatedTs)}</span>
        </div>
    );
}

function RainfallSection({ data, updatedTs }) {
    const active = data?.active || [];
    const total = data?.total_stations || 0;
    const raining = data?.raining_stations || 0;

    return (
        <div style={s.section}>
            <SectionHeader icon="🌧" title="Rainfall" updatedTs={updatedTs} count={raining > 0 ? `${raining}/${total}` : null} />
            {active.length === 0 ? (
                <div style={s.emptyText}>No rainfall detected across {total} stations</div>
            ) : (
                <div style={s.stationList}>
                    {active.slice(0, 8).map((st) => {
                        const level = rainfallLevel(st.reading);
                        return (
                            <div key={st.id} style={s.stationRow}>
                                <div style={{ ...s.stationDot, background: level.color }} />
                                <span style={s.stationName}>{st.name}</span>
                                <span style={s.stationReading}>
                                    <span style={{ color: level.color, fontWeight: 600 }}>{st.reading}</span>
                                    <span style={s.stationUnit}>mm</span>
                                </span>
                            </div>
                        );
                    })}
                    {active.length > 8 && (
                        <div style={s.moreText}>+{active.length - 8} more stations</div>
                    )}
                </div>
            )}
        </div>
    );
}

function WeatherSection({ data, updatedTs }) {
    const forecasts = data?.forecasts || [];
    const validTo = data?.valid_to || '';

    // Group forecasts by type for a compact summary
    const grouped = {};
    for (const f of forecasts) {
        const key = f.forecast;
        if (!grouped[key]) grouped[key] = { forecast: key, areas: [] };
        grouped[key].areas.push(f.area);
    }
    const groups = Object.values(grouped).sort((a, b) => b.areas.length - a.areas.length);

    return (
        <div style={s.section}>
            <SectionHeader icon="🌤" title="Weather (2hr)" updatedTs={updatedTs} />
            {groups.length === 0 ? (
                <div style={s.emptyText}>No forecast data available</div>
            ) : (
                <div style={s.weatherGrid}>
                    {groups.slice(0, 6).map((g) => (
                        <div key={g.forecast} style={s.weatherCard}>
                            <span style={s.weatherEmoji}>{weatherIcon(g.forecast)}</span>
                            <span style={s.weatherForecast}>{g.forecast}</span>
                            <span style={s.weatherCount}>{g.areas.length} areas</span>
                        </div>
                    ))}
                </div>
            )}
            {validTo && (
                <div style={s.validUntil}>Valid until {new Date(validTo).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div>
            )}
        </div>
    );
}

function PsiSection({ data, updatedTs }) {
    const regions = data?.regions || {};
    const national = data?.national_psi;
    const level = psiLevel(national);

    return (
        <div style={s.section}>
            <SectionHeader icon="💨" title="Air Quality (PSI)" updatedTs={updatedTs} />
            {national != null ? (
                <>
                    <div style={s.psiHero}>
                        <span style={{ ...s.psiValue, color: level.color }}>{national}</span>
                        <span style={{ ...s.psiLabel, color: level.color }}>{level.label}</span>
                    </div>
                    <div style={s.psiGrid}>
                        {Object.entries(regions).map(([region, vals]) => {
                            const rl = psiLevel(vals?.psi);
                            return (
                                <div key={region} style={s.psiRegion}>
                                    <span style={s.psiRegionName}>{region}</span>
                                    <span style={{ ...s.psiRegionVal, color: rl.color }}>{vals?.psi ?? '—'}</span>
                                    {vals?.pm25 != null && (
                                        <span style={s.psiPm25}>PM2.5: {vals.pm25}</span>
                                    )}
                                </div>
                            );
                        })}
                    </div>
                </>
            ) : (
                <div style={s.emptyText}>No air quality data available</div>
            )}
        </div>
    );
}

function CameraSection({ data, updatedTs }) {
    const cameras = data?.cameras || [];
    const [expanded, setExpanded] = useState(null);

    if (cameras.length === 0) {
        return (
            <div style={s.section}>
                <SectionHeader icon="📹" title="Traffic Cameras" updatedTs={updatedTs} />
                <div style={s.emptyText}>No camera feeds available</div>
            </div>
        );
    }

    // Show a subset for the grid
    const shown = cameras.slice(0, 12);

    return (
        <div style={s.section}>
            <SectionHeader icon="📹" title="Traffic Cameras" updatedTs={updatedTs} count={cameras.length} />
            {expanded && (
                <div style={s.cameraExpanded} onClick={() => setExpanded(null)}>
                    <img
                        src={expanded.image_url}
                        alt={`Camera ${expanded.id}`}
                        style={s.cameraExpandedImg}
                        onError={(e) => { e.target.style.display = 'none'; }}
                    />
                    <div style={s.cameraExpandedLabel}>
                        Camera {expanded.id} • {expanded.lat?.toFixed(4)}, {expanded.lng?.toFixed(4)}
                    </div>
                </div>
            )}
            <div style={s.cameraGrid}>
                {shown.map((cam) => (
                    <div
                        key={cam.id}
                        style={s.cameraThumbnailWrap}
                        onClick={() => setExpanded(cam)}
                        title={`Camera ${cam.id}`}
                    >
                        <img
                            src={cam.image_url}
                            alt={`Cam ${cam.id}`}
                            style={s.cameraThumbnail}
                            loading="lazy"
                            onError={(e) => {
                                e.target.style.display = 'none';
                                e.target.parentElement.style.background = 'var(--chip-bg)';
                            }}
                        />
                        <div style={s.cameraThumbnailId}>{cam.id}</div>
                    </div>
                ))}
            </div>
            {cameras.length > 12 && (
                <div style={s.moreText}>{cameras.length - 12} more cameras available</div>
            )}
        </div>
    );
}

/* ── Main Panel ──────────────────────────────────────────────────── */

export default function SensorPanel({ sensors }) {
    if (!sensors) {
        return (
            <div style={s.panel}>
                <div style={s.loadingWrap}>
                    <div style={s.loadingPulse} />
                    <span style={s.loadingText}>Connecting to infrastructure sensors…</span>
                </div>
            </div>
        );
    }

    const lu = sensors.last_updated || {};
    const feedCount = Object.keys(lu).length;

    return (
        <div style={s.panel}>
            {/* Feed status bar */}
            <div style={s.feedBar}>
                <div style={s.feedDot} />
                <span style={s.feedLabel}>{feedCount} live feed{feedCount !== 1 ? 's' : ''}</span>
                <span style={s.feedSource}>data.gov.sg</span>
            </div>

            <div style={s.scrollArea}>
                <RainfallSection data={sensors.rainfall} updatedTs={lu.rainfall} />
                <WeatherSection data={sensors.weather} updatedTs={lu.weather} />
                <PsiSection data={sensors.psi} updatedTs={lu.psi} />
                <CameraSection data={sensors.cameras} updatedTs={lu.cameras} />
            </div>
        </div>
    );
}

/* ── Styles ───────────────────────────────────────────────────────── */

const s = {
    panel: {
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        overflow: 'hidden',
    },
    loadingWrap: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 12,
        flex: 1,
        padding: 24,
    },
    loadingPulse: {
        width: 8,
        height: 8,
        borderRadius: '50%',
        background: 'var(--cyan)',
        animation: 'pulse 1.5s ease-in-out infinite',
    },
    loadingText: {
        fontSize: 11,
        color: 'var(--text-tertiary)',
        textAlign: 'center',
    },
    feedBar: {
        display: 'flex',
        alignItems: 'center',
        gap: 6,
        padding: '8px 12px',
        borderBottom: '0.5px solid var(--separator)',
        flexShrink: 0,
    },
    feedDot: {
        width: 6,
        height: 6,
        borderRadius: '50%',
        background: 'var(--green)',
        boxShadow: '0 0 6px var(--green)',
        animation: 'pulse 2s ease-in-out infinite',
    },
    feedLabel: {
        fontSize: 10,
        fontWeight: 600,
        color: 'var(--text-secondary)',
        textTransform: 'uppercase',
        letterSpacing: '0.03em',
    },
    feedSource: {
        fontSize: 9,
        color: 'var(--text-tertiary)',
        marginLeft: 'auto',
        fontFamily: 'var(--mono)',
    },
    scrollArea: {
        flex: 1,
        overflow: 'auto',
        padding: '4px 0',
    },

    /* Sections */
    section: {
        padding: '10px 12px',
        borderBottom: '0.5px solid var(--separator)',
    },
    sectionHeader: {
        display: 'flex',
        alignItems: 'center',
        gap: 6,
        marginBottom: 8,
    },
    sectionIcon: {
        fontSize: 13,
    },
    sectionTitle: {
        fontSize: 11,
        fontWeight: 600,
        color: 'var(--text-primary)',
        textTransform: 'uppercase',
        letterSpacing: '0.03em',
    },
    sectionCount: {
        fontSize: 9,
        fontWeight: 600,
        fontFamily: 'var(--mono)',
        padding: '1px 5px',
        borderRadius: 8,
        background: 'var(--tint-dim)',
        color: 'var(--tint)',
    },
    sectionTime: {
        marginLeft: 'auto',
        fontSize: 9,
        color: 'var(--text-tertiary)',
        fontFamily: 'var(--mono)',
    },
    emptyText: {
        fontSize: 11,
        color: 'var(--text-tertiary)',
        fontStyle: 'italic',
        padding: '4px 0',
    },
    moreText: {
        fontSize: 10,
        color: 'var(--text-tertiary)',
        marginTop: 4,
        textAlign: 'center',
    },

    /* Rainfall */
    stationList: {
        display: 'flex',
        flexDirection: 'column',
        gap: 3,
    },
    stationRow: {
        display: 'flex',
        alignItems: 'center',
        gap: 6,
        padding: '3px 4px',
        borderRadius: 4,
        transition: 'background 0.12s',
    },
    stationDot: {
        width: 5,
        height: 5,
        borderRadius: '50%',
        flexShrink: 0,
    },
    stationName: {
        fontSize: 11,
        color: 'var(--text-secondary)',
        flex: 1,
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        whiteSpace: 'nowrap',
    },
    stationReading: {
        fontSize: 11,
        fontFamily: 'var(--mono)',
        display: 'flex',
        alignItems: 'baseline',
        gap: 2,
    },
    stationUnit: {
        fontSize: 9,
        color: 'var(--text-tertiary)',
    },

    /* Weather */
    weatherGrid: {
        display: 'grid',
        gridTemplateColumns: 'repeat(2, 1fr)',
        gap: 4,
    },
    weatherCard: {
        display: 'flex',
        alignItems: 'center',
        gap: 5,
        padding: '5px 6px',
        borderRadius: 5,
        background: 'var(--chip-bg)',
        border: '0.5px solid var(--chip-border)',
    },
    weatherEmoji: {
        fontSize: 14,
    },
    weatherForecast: {
        fontSize: 10,
        color: 'var(--text-secondary)',
        flex: 1,
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        whiteSpace: 'nowrap',
    },
    weatherCount: {
        fontSize: 9,
        color: 'var(--text-tertiary)',
        fontFamily: 'var(--mono)',
        flexShrink: 0,
    },
    validUntil: {
        fontSize: 9,
        color: 'var(--text-tertiary)',
        marginTop: 4,
        textAlign: 'right',
    },

    /* PSI */
    psiHero: {
        display: 'flex',
        alignItems: 'baseline',
        gap: 8,
        padding: '4px 0 8px',
    },
    psiValue: {
        fontSize: 28,
        fontWeight: 700,
        fontFamily: 'var(--mono)',
        lineHeight: 1,
    },
    psiLabel: {
        fontSize: 11,
        fontWeight: 600,
        textTransform: 'uppercase',
        letterSpacing: '0.03em',
    },
    psiGrid: {
        display: 'grid',
        gridTemplateColumns: 'repeat(3, 1fr)',
        gap: 4,
    },
    psiRegion: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 1,
        padding: '4px',
        borderRadius: 4,
        background: 'var(--chip-bg)',
    },
    psiRegionName: {
        fontSize: 9,
        color: 'var(--text-tertiary)',
        textTransform: 'capitalize',
        fontWeight: 500,
    },
    psiRegionVal: {
        fontSize: 13,
        fontWeight: 600,
        fontFamily: 'var(--mono)',
    },
    psiPm25: {
        fontSize: 8,
        color: 'var(--text-tertiary)',
        fontFamily: 'var(--mono)',
    },

    /* Cameras */
    cameraGrid: {
        display: 'grid',
        gridTemplateColumns: 'repeat(3, 1fr)',
        gap: 4,
    },
    cameraThumbnailWrap: {
        position: 'relative',
        borderRadius: 4,
        overflow: 'hidden',
        cursor: 'pointer',
        aspectRatio: '4/3',
        background: 'var(--bg-content)',
        border: '0.5px solid var(--chip-border)',
        transition: 'transform 0.12s, box-shadow 0.12s',
    },
    cameraThumbnail: {
        width: '100%',
        height: '100%',
        objectFit: 'cover',
        display: 'block',
    },
    cameraThumbnailId: {
        position: 'absolute',
        bottom: 0,
        left: 0,
        right: 0,
        background: 'linear-gradient(transparent, rgba(0,0,0,0.7))',
        color: '#fff',
        fontSize: 8,
        fontFamily: 'var(--mono)',
        padding: '8px 3px 2px',
        textAlign: 'center',
    },
    cameraExpanded: {
        marginBottom: 6,
        borderRadius: 6,
        overflow: 'hidden',
        cursor: 'pointer',
        border: '0.5px solid var(--chip-border)',
        position: 'relative',
    },
    cameraExpandedImg: {
        width: '100%',
        height: 'auto',
        display: 'block',
    },
    cameraExpandedLabel: {
        position: 'absolute',
        bottom: 0,
        left: 0,
        right: 0,
        background: 'linear-gradient(transparent, rgba(0,0,0,0.8))',
        color: '#fff',
        fontSize: 10,
        fontFamily: 'var(--mono)',
        padding: '16px 6px 4px',
    },
};
