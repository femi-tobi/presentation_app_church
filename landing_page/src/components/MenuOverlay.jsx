import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Link } from 'react-router-dom';

const MenuOverlay = ({ isOpen, onClose }) => {
  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ opacity: 0, y: '-100%' }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: '-100%' }}
          transition={{ type: 'spring', damping: 20, stiffness: 100 }}
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            width: '100%',
            height: '100vh',
            background: 'var(--bg-yellow)',
            zIndex: 9999,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            color: 'var(--text-primary)'
          }}
        >
          <button 
            onClick={onClose}
            className="btn-solid"
            style={{ position: 'absolute', top: '24px', right: '24px', background: 'var(--border-dark)', color: 'white' }}
          >
            ✕ Close
          </button>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '32px', textAlign: 'center', fontSize: '3rem', fontWeight: 900 }}>
            <Link to="/" onClick={onClose} style={{ color: 'var(--border-dark)', textDecoration: 'none' }}>Home</Link>
            <Link to="/about" onClick={onClose} style={{ color: 'var(--border-dark)', textDecoration: 'none' }}>About Us</Link>
            <Link to="/docs" onClick={onClose} style={{ color: 'var(--border-dark)', textDecoration: 'none' }}>Documentation</Link>
            <Link to="/support" onClick={onClose} style={{ color: 'var(--border-dark)', textDecoration: 'none' }}>Support</Link>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

export default MenuOverlay;
