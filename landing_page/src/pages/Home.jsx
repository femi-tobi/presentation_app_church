import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import PageTransition from '../components/PageTransition';
import MenuOverlay from '../components/MenuOverlay';

const Home = () => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  return (
    <PageTransition>
      <MenuOverlay isOpen={isMenuOpen} onClose={() => setIsMenuOpen(false)} />
      {/* Navbar */}
      <nav className="navbar">
        <div className="container nav-container">
          <div className="logo-container">
            {/* The actual logo copied from assets */}
            <img src="/app_icon.ico" alt="LiveDeck Logo" style={{ width: '48px', height: '48px' }} />
            <span className="logo-text">LiveDeck</span>
          </div>
          <div>
            <button 
              className="btn-solid" 
              style={{ background: '#FF7EB3' }}
              onClick={() => setIsMenuOpen(true)}
            >
              ≡ Menu
            </button>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="section-hero">
        <div className="container">
          
          <motion.h1 
            className="hero-title"
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ type: 'spring', bounce: 0.5 }}
          >
            Present Flawlessly<br />
            Inspire the World
          </motion.h1>
          
          <p style={{ fontSize: '1.5rem', fontWeight: 600, color: 'var(--text-muted)' }}>
            Connect instantly with pixel-perfect projection.
          </p>

          <div className="store-badges">
            <button className="store-badge">▶ Get it on Windows</button>
            <button className="store-badge" style={{ background: '#FFDD00', color: 'black' }}>★ Remote Control</button>
          </div>

          {/* Floating Stickers */}
          <motion.div 
            className="sticker sticker-pink" 
            style={{ top: '200px', left: '15%' }}
            animate={{ y: [0, -10, 0] }}
            transition={{ repeat: Infinity, duration: 3, ease: 'easeInOut' }}
          >
            Wireless!
          </motion.div>

          <motion.div 
            className="sticker sticker-blue" 
            style={{ top: '150px', right: '18%' }}
            animate={{ y: [0, 15, 0] }}
            transition={{ repeat: Infinity, duration: 4, ease: 'easeInOut' }}
          >
            Zero Latency
          </motion.div>

          <motion.div 
            className="sticker sticker-green" 
            style={{ top: '350px', left: '20%' }}
            animate={{ y: [0, 8, 0], rotate: [5, 10, 5] }}
            transition={{ repeat: Infinity, duration: 3.5, ease: 'easeInOut' }}
          >
            Perfect Vibes
          </motion.div>

          {/* Overlapping Mockups */}
          <div className="mockup-group">
            <motion.div 
              className="mockup-desktop"
              initial={{ y: 100, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              transition={{ delay: 0.1 }}
            >
              <div className="screen-content" style={{ background: '#22C55E' }}>Desktop Audience View</div>
            </motion.div>
            
            <motion.div 
              className="mockup-phone mockup-phone-offset"
              initial={{ y: 100, x: 280, rotate: 10, opacity: 0 }}
              animate={{ y: 30, x: 280, rotate: 10, opacity: 1 }}
              transition={{ delay: 0.2 }}
            >
              <div className="screen-content">Phone Remote</div>
            </motion.div>
          </div>
        </div>
      </section>

      {/* Blue Section */}
      <section className="section-blue">
        <div className="container" style={{ display: 'flex', alignItems: 'center', gap: '60px' }}>
          <div style={{ flex: 1 }}>
            <h2 className="section-title">Straight to the<br />real presentation</h2>
            <p style={{ fontSize: '1.25rem', fontWeight: 600 }}>
              Controlling your slides is effortless. Import your PPTX, connect your phone, and dive right into the message. No IP addresses, no firewall rules.
            </p>
          </div>
          <div style={{ flex: 1 }}>
             {/* Big chunky image placeholder */}
             <div style={{ width: '100%', height: '400px', background: '#FF7EB3', borderRadius: '40px', border: '8px solid var(--border-dark)', boxShadow: 'var(--shadow-sticker)' }}></div>
          </div>
        </div>
      </section>

      {/* Yellow Features Section */}
      <section className="section-yellow">
        <div className="container">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
            <h2 className="section-title" style={{ margin: 0 }}>Flow with the<br />moment</h2>
            <p style={{ maxWidth: '400px', fontSize: '1.1rem', fontWeight: 600 }}>
              Seamless automatic updates, dynamic backgrounds, and instantaneous text rendering. 
            </p>
          </div>

          <div className="polaroid-grid">
            <div className="polaroid">
               <div className="sticker sticker-blue" style={{ top: '-20px', left: '-20px', zIndex: 10 }}>⚡ Fast</div>
               <div className="polaroid-image"></div>
            </div>
            
            <div className="polaroid">
               <div className="sticker sticker-pink" style={{ top: '-20px', right: '-20px', zIndex: 10 }}>🔥 Smooth</div>
               <div className="polaroid-image" style={{ background: '#FF7EB3' }}></div>
            </div>
            
            <div className="polaroid">
               <div className="sticker sticker-green" style={{ bottom: '20px', right: '-20px', zIndex: 10 }}>✨ Magic</div>
               <div className="polaroid-image" style={{ background: '#22C55E' }}></div>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="section-footer">
        <div className="container">
           <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '60px' }}>
             <span className="logo-text" style={{ fontSize: '4rem' }}>LiveDeck</span>
             <div className="store-badges" style={{ marginTop: 0 }}>
               <button className="store-badge">Download App</button>
             </div>
           </div>
           
           <div style={{ display: 'flex', gap: '80px', fontWeight: 600 }}>
             <div>
               <h4 style={{ marginBottom: '16px' }}>About</h4>
               <Link to="/about" style={{ display: 'block', color: 'inherit', textDecoration: 'none', marginBottom: '8px' }}>Our Story</Link>
               <Link to="/about" style={{ display: 'block', color: 'inherit', textDecoration: 'none', marginBottom: '8px' }}>Careers</Link>
             </div>
             <div>
               <h4 style={{ marginBottom: '16px' }}>Support</h4>
               <Link to="/support" style={{ display: 'block', color: 'inherit', textDecoration: 'none', marginBottom: '8px' }}>Help Center</Link>
               <Link to="/support" style={{ display: 'block', color: 'inherit', textDecoration: 'none', marginBottom: '8px' }}>Safety Tools</Link>
             </div>
             <div>
               <h4 style={{ marginBottom: '16px' }}>Legal</h4>
               <Link to="/" style={{ display: 'block', color: 'inherit', textDecoration: 'none', marginBottom: '8px' }}>Privacy Policy</Link>
               <Link to="/" style={{ display: 'block', color: 'inherit', textDecoration: 'none', marginBottom: '8px' }}>Terms of Service</Link>
             </div>
           </div>
        </div>
      </footer>
    </PageTransition>
  );
};

export default Home;
