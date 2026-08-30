import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import PageTransition from '../components/PageTransition';

const About = () => {
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
            The Problem<br/>We Are Solving
          </motion.h1>
          
          <div className="sticker sticker-blue" style={{ top: '150px', right: '15%' }}>Too Many Apps!</div>
          <div className="sticker sticker-pink" style={{ top: '250px', left: '15%' }}>Messy Cables</div>
        </div>
      </section>

      <section className="section-blue" style={{ minHeight: '40vh' }}>
        <div className="container" style={{ textAlign: 'center' }}>
          <h2 className="section-title">End the juggling act.</h2>
          <p style={{ fontSize: '1.25rem', fontWeight: 600, maxWidth: '800px', margin: '0 auto 40px auto' }}>
            For years, running a live service meant constantly switching between a half-dozen different platforms. You needed one app for your sermon slides, another for the Bible verses, a separate web window for GHS (Gospel Hymns and Songs), another folder for choir notes, and yet another tool just to get everything onto the projector.
          </p>
          <p style={{ fontSize: '1.25rem', fontWeight: 600, maxWidth: '800px', margin: '0 auto' }}>
            It was chaotic. It required a highly trained volunteer just to make sure the wrong window wasn't accidentally shown to the audience.
          </p>
        </div>
      </section>

      <section className="section-yellow" style={{ minHeight: '50vh', position: 'relative' }}>
        <div className="container" style={{ textAlign: 'center' }}>
          <div className="sticker sticker-green" style={{ top: '-30px', left: '50%', transform: 'translateX(-50%)' }}>The Solution</div>
          
          <h2 className="section-title" style={{ marginTop: '40px' }}>Everything embedded in one.</h2>
          <p style={{ fontSize: '1.25rem', fontWeight: 600, maxWidth: '800px', margin: '0 auto 60px auto' }}>
            We built LiveDeck so you don't have to use different platforms for your service anymore. Everything is now natively embedded in one beautiful, reliable engine.
          </p>

          <div className="polaroid-grid">
            <div className="polaroid" style={{ textAlign: 'center', paddingTop: '30px' }}>
              <h3 style={{ fontSize: '1.5rem', marginBottom: '8px' }}>GHS & Choir</h3>
              <p style={{ fontWeight: 600, color: 'var(--text-muted)' }}>Built-in hymn lyrics and choir songs.</p>
            </div>
            <div className="polaroid" style={{ textAlign: 'center', paddingTop: '30px' }}>
              <h3 style={{ fontSize: '1.5rem', marginBottom: '8px' }}>Bible Integration</h3>
              <p style={{ fontWeight: 600, color: 'var(--text-muted)' }}>Instant overlays for any scripture.</p>
            </div>
            <div className="polaroid" style={{ textAlign: 'center', paddingTop: '30px' }}>
              <h3 style={{ fontSize: '1.5rem', marginBottom: '8px' }}>Sermons & Notes</h3>
              <p style={{ fontWeight: 600, color: 'var(--text-muted)' }}>Seamless PPTX imports and live notes.</p>
            </div>
          </div>

          <div style={{ marginTop: '80px' }}>
            <Link to="/" className="btn-solid" style={{ fontSize: '1.2rem', padding: '20px 40px', background: 'var(--border-dark)' }}>
              Download LiveDeck Now
            </Link>
          </div>
        </div>
      </section>
    </PageTransition>
  );
};

export default About;
