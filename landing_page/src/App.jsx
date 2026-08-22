import React from 'react';
import { BrowserRouter, Routes, Route, useLocation } from 'react-router-dom';
import { AnimatePresence } from 'framer-motion';

// Pages
import Home from './pages/Home';
import About from './pages/About';

// Create a wrapper component for AnimatePresence to work with routing
function AnimatedRoutes() {
  const location = useLocation();
  
  return (
    // mode="wait" ensures the exit animation finishes before the enter animation starts
    <AnimatePresence mode="wait">
      <Routes location={location} key={location.pathname}>
        <Route path="/" element={<Home />} />
        <Route path="/about" element={<About />} />
      </Routes>
    </AnimatePresence>
  );
}

function App() {
  return (
    <BrowserRouter>
      <div className="app-container">
        {/* Navigation could go here */}
        <AnimatedRoutes />
      </div>
    </BrowserRouter>
  );
}

export default App;
