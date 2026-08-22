import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import PageTransition from '../components/PageTransition';

const Home = () => {
  return (
    <PageTransition>
      <div className="section" style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
        <div className="container" style={{ textAlign: 'center' }}>
          
          <motion.h1 
            className="text-gradient" 
            style={{ fontSize: '4rem', marginBottom: '20px' }}
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2, duration: 0.6 }}
          >
            Present Flawlessly.<br />
            <span className="text-gradient-primary">Inspire Effortlessly.</span>
          </motion.h1>
          
          <motion.p 
            style={{ fontSize: '1.2rem', color: 'var(--text-muted)', marginBottom: '40px', maxWidth: '600px', margin: '0 auto 40px auto' }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.4, duration: 0.6 }}
          >
            The next-generation presentation tool for modern churches and events. 
            Wireless control, automatic updates, and stunning pixel-perfect projection.
          </motion.p>
          
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: 0.6, duration: 0.5, type: 'spring' }}
            style={{ display: 'flex', gap: '20px', justifyContent: 'center', marginBottom: '80px' }}
          >
            <button className="btn-primary">Download for Windows</button>
            <Link to="/about">
              <button className="btn-outline">Learn More</button>
            </Link>
          </motion.div>
          
          {/* Glassmorphism Feature Cards Area */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '30px' }}>
            {[
              { title: 'Wireless Remote', desc: 'Control your presentation directly from your phone.' },
              { title: 'Bible Integration', desc: 'Instantly display beautiful lower-third verses.' },
              { title: 'Zero Configuration', desc: 'It just works out of the box with zero network setup.' }
            ].map((feature, i) => (
              <motion.div 
                key={i}
                className="glass-card"
                initial={{ opacity: 0, y: 50 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.8 + (i * 0.1), duration: 0.5 }}
              >
                <h3 style={{ marginBottom: '10px', color: 'var(--primary-glow)' }}>{feature.title}</h3>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>{feature.desc}</p>
              </motion.div>
            ))}
          </div>

        </div>
      </div>
    </PageTransition>
  );
};

export default Home;
