import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import PageTransition from '../components/PageTransition';

const About = () => {
  return (
    <PageTransition>
      <div className="section" style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
        <div className="container" style={{ textAlign: 'center', maxWidth: '800px' }}>
          
          <motion.h1 
            className="text-gradient" 
            style={{ fontSize: '3rem', marginBottom: '20px' }}
          >
            Built for the modern church.
          </motion.h1>
          
          <motion.p 
            style={{ fontSize: '1.2rem', color: 'var(--text-muted)', marginBottom: '40px' }}
          >
            We realized that existing presentation software was either too complex, too expensive, or stuck in the past. LiveDeck was built from the ground up to be lightweight, beautiful, and completely wireless.
          </motion.p>
          
          <div className="glass-panel" style={{ padding: '40px', marginBottom: '40px' }}>
            <h2 style={{ color: 'var(--primary-glow)', marginBottom: '20px' }}>Our Mission</h2>
            <p style={{ color: 'var(--text-muted)' }}>
              To provide a flawless pixel-perfect projection experience that stays out of your way, so you can focus on the message, not the software.
            </p>
          </div>

          <Link to="/">
            <button className="btn-outline">← Back Home</button>
          </Link>
          
        </div>
      </div>
    </PageTransition>
  );
};

export default About;
