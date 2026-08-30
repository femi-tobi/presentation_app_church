import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import PageTransition from '../components/PageTransition';

const Docs = () => {
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
            Documentation
          </motion.h1>
          <p style={{ fontSize: '1.5rem', fontWeight: 600, maxWidth: '600px', margin: '0 auto', color: 'var(--text-muted)' }}>
            Learn how to use LiveDeck's integrated tools for GHS, Bible, Sermons, and Choir.
          </p>
        </div>
      </section>

      <section className="section-blue" style={{ minHeight: '60vh' }}>
        <div className="container">
          
          <div style={{ background: 'white', borderRadius: '40px', padding: '60px', border: '8px solid var(--border-dark)', boxShadow: 'var(--shadow-sticker)', textAlign: 'left' }}>
            <h2 style={{ fontSize: '2.5rem', marginBottom: '24px' }}>1. GHS & Choir Songs</h2>
            <p style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: '40px', color: 'var(--text-muted)' }}>
              LiveDeck comes pre-loaded with the Gospel Hymns and Songs (GHS). 
              Simply type the hymn number in the search bar, and the lyrics will instantly format themselves for the audience view. You can also import custom choir songs via text files.
            </p>

            <h2 style={{ fontSize: '2.5rem', marginBottom: '24px' }}>2. Bible Integration</h2>
            <p style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: '40px', color: 'var(--text-muted)' }}>
              We support multiple versions (KJV, NIV, etc.). You can trigger a Bible verse as a full-screen slide or as a Lower Third overlay across a live video feed. Use the phone remote to quickly jump between chapters.
            </p>

            <h2 style={{ fontSize: '2.5rem', marginBottom: '24px' }}>3. Sermons & Notes</h2>
            <p style={{ fontSize: '1.2rem', fontWeight: 600, color: 'var(--text-muted)' }}>
              You don't need PowerPoint open anymore. Import your `.pptx` directly into LiveDeck. The presenter can see their private notes on the Phone Remote, while the audience only sees the slides.
            </p>
          </div>

        </div>
      </section>
    </PageTransition>
  );
};

export default Docs;
