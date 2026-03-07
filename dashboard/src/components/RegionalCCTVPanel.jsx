import React, { useMemo } from 'react';

// Haversine distance in meters
function getDistance(lat1, lon1, lat2, lon2) {
    const R = 6371e3; // Earth's radius in meters
    const p1 = (lat1 * Math.PI) / 180;
    const p2 = (lat2 * Math.PI) / 180;
    const dp = ((lat2 - lat1) * Math.PI) / 180;
    const dl = ((lon2 - lon1) * Math.PI) / 180;
    const a = Math.sin(dp / 2) * Math.sin(dp / 2) + Math.cos(p1) * Math.cos(p2) * Math.sin(dl / 2) * Math.sin(dl / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

export default function RegionalCCTVPanel({ sensors, region, onClose }) {
    const RADIUS = 3000; // 3km

    const cameras = useMemo(() => {
        if (!sensors?.cameras?.cameras || !region) return [];
        return sensors.cameras.cameras
            .map((c) => ({
                ...c,
                dist: getDistance(region.lat, region.lng, c.lat, c.lng),
            }))
            .filter((c) => c.dist <= RADIUS)
            .sort((a, b) => a.dist - b.dist);
    }, [sensors, region]);

    if (!region) return null;

    return (
        <div style={styles.overlay}>
            <div style={styles.panel}>
                <div style={styles.header}>
                    <div>
                        <h3 style={styles.title}>Regional CCTV Scan</h3>
                        <p style={styles.subtitle}>{cameras.length} cameras within 3km</p>
                    </div>
                    <button style={styles.closeBtn} onClick={onClose}>×</button>
                </div>

                <div style={styles.gridContainer}>
                    {cameras.length === 0 ? (
                        <div style={styles.empty}>No cameras found in this region.</div>
                    ) : (
                        <div style={styles.grid}>
                            {cameras.map((c) => (
                                <div key={c.id} style={styles.card}>
                                    <div style={styles.imgWrapper}>
                                        <img src={c.image_url} alt={`Camera ${c.id}`} style={styles.img} />
                                        <div style={styles.imgOverlay}>
                                            <span>ID: {c.id}</span>
                                            <span>{(c.dist / 1000).toFixed(1)} km</span>
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}

const styles = {
    overlay: {
        position: 'absolute',
        top: 60,
        right: 360, // left of sidebar
        bottom: 0,
        width: 400,
        background: 'var(--bg-glass)',
        backdropFilter: 'blur(20px)',
        WebkitBackdropFilter: 'blur(20px)',
        borderLeft: '1px solid var(--border)',
        boxShadow: '-10px 0 30px rgba(0,0,0,0.1)',
        display: 'flex',
        flexDirection: 'column',
        zIndex: 50,
        animation: 'slideIn 0.3s cubic-bezier(0.16, 1, 0.3, 1)',
    },
    panel: {
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
    },
    header: {
        padding: '20px',
        borderBottom: '1px solid var(--border)',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'flex-start',
        background: 'rgba(0,0,0,0.05)',
    },
    title: {
        margin: 0,
        fontSize: 16,
        fontWeight: 700,
        color: 'var(--text-primary)',
        fontFamily: 'var(--system-font)',
        letterSpacing: '-0.02em',
    },
    subtitle: {
        margin: '4px 0 0',
        fontSize: 13,
        color: 'var(--text-secondary)',
        fontFamily: 'var(--system-font)',
    },
    closeBtn: {
        background: 'transparent',
        border: 'none',
        color: 'var(--text-primary)',
        fontSize: 24,
        lineHeight: 1,
        cursor: 'pointer',
        padding: '4px 8px',
        opacity: 0.6,
        transition: 'opacity 0.2s',
    },
    gridContainer: {
        flex: 1,
        overflowY: 'auto',
        padding: '16px',
        backgroundColor: 'var(--bg-primary)',
    },
    grid: {
        display: 'grid',
        gridTemplateColumns: '1fr 1fr',
        gap: '12px',
    },
    card: {
        background: 'var(--surface-color)',
        borderRadius: '10px',
        overflow: 'hidden',
        border: '1px solid var(--border)',
        boxShadow: '0 2px 8px rgba(0,0,0,0.05)',
    },
    imgWrapper: {
        position: 'relative',
        aspectRatio: '4/3',
        background: '#000',
    },
    img: {
        width: '100%',
        height: '100%',
        objectFit: 'cover',
        display: 'block',
    },
    imgOverlay: {
        position: 'absolute',
        bottom: 0,
        left: 0,
        right: 0,
        padding: '6px 8px',
        background: 'linear-gradient(to top, rgba(0,0,0,0.8), transparent)',
        display: 'flex',
        justifyContent: 'space-between',
        color: '#fff',
        fontSize: 11,
        fontWeight: 600,
        fontFamily: 'var(--mono-font)',
        textShadow: '0 1px 2px rgba(0,0,0,0.8)',
    },
    empty: {
        padding: '40px 20px',
        textAlign: 'center',
        color: 'var(--text-tertiary)',
        fontSize: 14,
        fontFamily: 'var(--system-font)',
    }
};
