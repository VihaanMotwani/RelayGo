import { useState, useMemo } from 'react';

/* ── Helpers ─────────────────────────────────────────────────────── */

function timeAgo(ts) {
    if (!ts) return '—';
    const secs = Math.floor((Date.now() / 1000) - ts);
    if (secs < 10) return 'just now';
    if (secs < 60) return `${secs}s ago`;
    if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
    return `${Math.floor(secs / 3600)}h ago`;
}

function haversine(lat1, lon1, lat2, lon2) {
    const R = 6371; // km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

const TYPE_CONFIG = {
    hospital: { icon: '🏥', label: 'Hospitals', color: 'var(--red)' },
    fire_station: { icon: '🚒', label: 'Fire Stations', color: 'var(--orange)' },
    shelter: { icon: '🛡️', label: 'Shelters', color: 'var(--green)' },
    police: { icon: '🚓', label: 'Police Stations', color: 'var(--cyan)' },
    clinic: { icon: '⚕️', label: 'Clinics', color: 'var(--tint)' },
};

/* ── Sub-components ──────────────────────────────────────────────── */

function SectionHeader({ icon, title, count, updatedTs }) {
    return (
        <div style={s.sectionHeader}>
            <span style={s.sectionIcon}>{icon}</span>
            <span style={s.sectionTitle}>{title}</span>
            {count != null && <span style={s.sectionCount}>{count}</span>}
            {updatedTs && <span style={s.sectionTime}>{timeAgo(updatedTs)}</span>}
        </div>
    );
}

function InfraCategoryList({ type, items }) {
    const config = TYPE_CONFIG[type] || { icon: '🏢', label: type, color: 'var(--text-secondary)' };
    const [expanded, setExpanded] = useState(false);

    if (!items || items.length === 0) return null;

    const limit = expanded ? items.length : 5;
    const shown = items.slice(0, limit);

    return (
        <div style={s.section}>
            <SectionHeader icon={config.icon} title={config.label} count={items.length} />
            <div style={s.facilityList}>
                {shown.map((item) => (
                    <div key={item.id} style={s.facilityRow}>
                        <div style={s.facilityEmoji}>{config.icon}</div>
                        <div style={s.facilityInfo}>
                            <span style={s.facilityName}>{item.name}</span>
                            <span style={s.facilityAddress}>
                                {item.dist != null ? <span style={{ color: 'var(--tint)' }}>{item.dist.toFixed(1)}km away • </span> : ''}
                                {item.address}
                            </span>
                        </div>
                    </div>
                ))}
                {!expanded && items.length > 5 && (
                    <button style={s.moreBtn} onClick={() => setExpanded(true)}>
                        Show {items.length - 5} more
                    </button>
                )}
                {expanded && items.length > 5 && (
                    <button style={s.moreBtn} onClick={() => setExpanded(false)}>
                        Show less
                    </button>
                )}
            </div>
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
                        <div style={s.cameraThumbnailId}>
                            {cam.id}
                            {cam.dist != null ? ` • ${cam.dist.toFixed(1)}km` : ''}
                        </div>
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

export default function InfraPanel({ sensors, focusedReport }) {
    const groupedInfra = useMemo(() => {
        const groups = { hospital: [], shelter: [], fire_station: [], police: [], clinic: [] };
        if (sensors?.infra) {
            let items = sensors.infra;
            if (focusedReport?.loc?.lat) {
                items = items.map(item => ({
                    ...item,
                    dist: haversine(focusedReport.loc.lat, focusedReport.loc.lng, item.lat, item.lon)
                })).sort((a, b) => a.dist - b.dist);
            }
            items.forEach(item => {
                if (groups[item.type]) {
                    groups[item.type].push(item);
                }
            });
        }
        return groups;
    }, [sensors?.infra, focusedReport]);

    const camerasWithDist = useMemo(() => {
        if (!sensors?.cameras?.cameras) return { cameras: [] };
        let cams = sensors.cameras.cameras;
        if (focusedReport?.loc?.lat) {
            cams = cams.map(cam => ({
                ...cam,
                dist: haversine(focusedReport.loc.lat, focusedReport.loc.lng, cam.lat, cam.lng)
            })).sort((a, b) => a.dist - b.dist);
        }
        return { ...sensors.cameras, cameras: cams };
    }, [sensors?.cameras, focusedReport]);

    if (!sensors || (!sensors.infra && !sensors.cameras)) {
        return (
            <div style={s.panel}>
                <div style={s.loadingWrap}>
                    <div style={s.loadingPulse} />
                    <span style={s.loadingText}>Loading critical infrastructure…</span>
                </div>
            </div>
        );
    }

    const lu = sensors.last_updated || {};

    return (
        <div style={s.panel}>
            {/* Infra Summary */}
            <div style={s.feedBar}>
                <div style={s.feedDot} />
                <span style={s.feedLabel}>
                    {sensors.infra?.length || 0} Facilities • {sensors.cameras?.total || 0} Cameras
                </span>
            </div>

            <div style={s.scrollArea}>
                <CameraSection data={camerasWithDist} updatedTs={lu.cameras} />
                <InfraCategoryList type="hospital" items={groupedInfra.hospital} />
                <InfraCategoryList type="fire_station" items={groupedInfra.fire_station} />
                <InfraCategoryList type="shelter" items={groupedInfra.shelter} />
                <InfraCategoryList type="police" items={groupedInfra.police} />
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
        background: 'var(--bg-panel)',
    },
    feedDot: {
        width: 6,
        height: 6,
        borderRadius: '50%',
        background: 'var(--green)',
        boxShadow: '0 0 6px var(--green)',
    },
    feedLabel: {
        fontSize: 10,
        fontWeight: 600,
        color: 'var(--text-secondary)',
        textTransform: 'uppercase',
        letterSpacing: '0.03em',
    },
    scrollArea: {
        flex: 1,
        overflow: 'auto',
        padding: '4px 0',
    },
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
        marginLeft: 'auto',
    },
    sectionTime: {
        fontSize: 9,
        color: 'var(--text-tertiary)',
        fontFamily: 'var(--mono)',
    },
    facilityList: {
        display: 'flex',
        flexDirection: 'column',
        gap: 4,
    },
    facilityRow: {
        display: 'flex',
        alignItems: 'flex-start',
        gap: 8,
        padding: '4px',
        borderRadius: 4,
        background: 'var(--chip-bg)',
        border: '0.5px solid var(--chip-border)',
    },
    facilityEmoji: {
        fontSize: 14,
        marginTop: 1,
        flexShrink: 0,
    },
    facilityInfo: {
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
    },
    facilityName: {
        fontSize: 11,
        fontWeight: 500,
        color: 'var(--text-primary)',
        whiteSpace: 'nowrap',
        overflow: 'hidden',
        textOverflow: 'ellipsis',
    },
    facilityAddress: {
        fontSize: 9,
        color: 'var(--text-tertiary)',
        whiteSpace: 'nowrap',
        overflow: 'hidden',
        textOverflow: 'ellipsis',
    },
    moreBtn: {
        background: 'transparent',
        border: 'none',
        color: 'var(--tint)',
        fontSize: 10,
        fontWeight: 600,
        cursor: 'pointer',
        padding: '4px 0',
        marginTop: 2,
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
