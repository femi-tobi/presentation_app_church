import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import PageTransition from '../components/PageTransition';

const Support = () => {
  return (
    <PageTransition>
      <nav className="navbar" style={{ background: 'var(--bg-warm-white)' }}>
        <div className="container nav-container">
          <Link to="/" style={{ textDecoration: 'none' }}>
            <div className="logo-container">
              <img src="/app_icon.ico" alt="LiveDeck Logo" style={{ width: '48px', height: '48px' }} />
              <span className="logo-text" style={{ fontSize: '1.5rem' }}>LiveDeck</span>
            </div>
          </Link>
          <Link to="/" className="btn-solid" style={{ background: 'var(--border-dark)' }}>
            Back Home
          </Link>
        </div>
      </nav>

      <section className="section-hero" style={{ paddingBottom: '60px' }}>
        <div className="container">
          <motion.h1 
            className="hero-title"
            initial={{ y: 30, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
          >
            How can we help?
          </motion.h1>
          <p style={{ fontSize: '1.5rem', fontWeight: 600, maxWidth: '600px', margin: '0 auto', color: 'var(--text-muted)' }}>
            Find answers, contact support, and learn how to master LiveDeck.
          </p>
        </div>
      </section>

      <section className="section-yellow" style={{ minHeight: '50vh' }}>
        <div className="container">
          <div className="polaroid-grid" style={{ marginTop: 0 }}>
            <div className="polaroid" style={{ textAlign: 'center', paddingTop: '40px' }}>
               <h3 style={{ fontSize: '2rem', marginBottom: '16px' }}>Documentation</h3>
               <p style={{ fontWeight: 600, color: 'var(--text-muted)' }}>Read our setup guides and tutorials.</p>
               <Link to="/docs" className="btn-solid" style={{ marginTop: '24px', textDecoration: 'none' }}>Read Docs</Link>
            </div>
            
            <div className="polaroid" style={{ textAlign: 'center', paddingTop: '40px' }}>
               <h3 style={{ fontSize: '2rem', marginBottom: '16px' }}>Community</h3>
               <p style={{ fontWeight: 600, color: 'var(--text-muted)' }}>Join the discussion and share tips.</p>
               <button className="btn-solid" style={{ marginTop: '24px', background: '#3B82F6' }}>Join Discord</button>
            </div>
            
            <div className="polaroid" style={{ textAlign: 'center', paddingTop: '40px' }}>
               <h3 style={{ fontSize: '2rem', marginBottom: '16px' }}>Contact Us</h3>
               <p style={{ fontWeight: 600, color: 'var(--text-muted)' }}>Email us directly for fast support.</p>
               <a href="mailto:adefemioluwatobi13@gmail.com" className="btn-solid" style={{ marginTop: '24px', background: '#FF7EB3', textDecoration: 'none' }}>Send Email</a>
            </div>
          </div>
        </div>
      </section>
    </PageTransition>
  );
};

export default Support;
