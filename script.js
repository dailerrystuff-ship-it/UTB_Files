const canvas = document.getElementById('particles');
const ctx = canvas.getContext('2d');

const pointer = { x: -1000, y: -1000 };
const particles = [];
const shootingStars = [];
const PARTICLE_COUNT = 180;

const towerData = {
  Scout: { dps: 24, range: 14, rate: 0.55, note: 'Лёгкая стартовая башня для ранних волн.' },
  Plasma: { dps: 62, range: 19, rate: 0.8, note: 'Стабильный mid-game урон по толпе.' },
  Titan: { dps: 130, range: 26, rate: 1.4, note: 'Тяжёлый late-game контроль и burst.' },
};

const state = {
  wave: 1,
  credits: 450,
  baseHp: 100,
  progress: 0,
  running: false,
};

let simInterval = null;

function resizeCanvas() {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
}

function createParticles() {
  particles.length = 0;
  for (let i = 0; i < PARTICLE_COUNT; i += 1) {
    particles.push({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      vx: (Math.random() - 0.5) * 0.5,
      vy: (Math.random() - 0.5) * 0.5,
      r: Math.random() * 1.6 + 0.6,
      glow: Math.random() * 0.5 + 0.4,
    });
  }
}

function maybeCreateShootingStar() {
  if (Math.random() < 0.015 && shootingStars.length < 4) {
    shootingStars.push({
      x: Math.random() * canvas.width,
      y: Math.random() * (canvas.height * 0.35),
      vx: 8 + Math.random() * 4,
      vy: 2 + Math.random() * 1.5,
      life: 0,
      ttl: 60,
    });
  }
}

function drawParticles() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  maybeCreateShootingStar();

  particles.forEach((p, i) => {
    p.x += p.vx;
    p.y += p.vy;

    if (p.x < 0 || p.x > canvas.width) p.vx *= -1;
    if (p.y < 0 || p.y > canvas.height) p.vy *= -1;

    const dx = pointer.x - p.x;
    const dy = pointer.y - p.y;
    const dist = Math.hypot(dx, dy);

    if (dist < 140 && dist > 0) {
      p.x -= (dx / dist) * 0.85;
      p.y -= (dy / dist) * 0.85;
    }

    ctx.beginPath();
    ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(155, 190, 255, ${p.glow})`;
    ctx.fill();

    for (let j = i + 1; j < particles.length; j += 1) {
      const p2 = particles[j];
      const d = Math.hypot(p.x - p2.x, p.y - p2.y);
      if (d < 88) {
        ctx.beginPath();
        ctx.moveTo(p.x, p.y);
        ctx.lineTo(p2.x, p2.y);
        ctx.strokeStyle = `rgba(98, 125, 255, ${0.22 - d / 550})`;
        ctx.lineWidth = 1;
        ctx.stroke();
      }
    }
  });

  for (let i = shootingStars.length - 1; i >= 0; i -= 1) {
    const star = shootingStars[i];
    star.x += star.vx;
    star.y += star.vy;
    star.life += 1;

    ctx.beginPath();
    ctx.moveTo(star.x, star.y);
    ctx.lineTo(star.x - 30, star.y - 8);
    ctx.strokeStyle = `rgba(135, 212, 255, ${1 - star.life / star.ttl})`;
    ctx.lineWidth = 2;
    ctx.stroke();

    if (star.life >= star.ttl) shootingStars.splice(i, 1);
  }

  requestAnimationFrame(drawParticles);
}

function setRevealObserver() {
  const observer = new IntersectionObserver(
    entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
        }
      });
    },
    { threshold: 0.14 }
  );

  document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
}

function initCounters() {
  const counters = document.querySelectorAll('.stat-number');
  const started = new WeakSet();

  const observer = new IntersectionObserver(
    entries => {
      entries.forEach(entry => {
        if (!entry.isIntersecting || started.has(entry.target)) return;
        started.add(entry.target);

        const target = Number(entry.target.dataset.target || 0);
        let current = 0;
        const increment = Math.max(1, Math.floor(target / 60));

        const tick = () => {
          current += increment;
          if (current >= target) {
            entry.target.textContent = String(target);
            return;
          }
          entry.target.textContent = String(current);
          requestAnimationFrame(tick);
        };

        tick();
      });
    },
    { threshold: 0.6 }
  );

  counters.forEach(counter => observer.observe(counter));
}

function initTilt() {
  document.querySelectorAll('.tilt-card').forEach(card => {
    card.addEventListener('mousemove', e => {
      const rect = card.getBoundingClientRect();
      const x = (e.clientX - rect.left) / rect.width - 0.5;
      const y = (e.clientY - rect.top) / rect.height - 0.5;
      card.style.transform = `perspective(900px) rotateX(${(-y * 7).toFixed(2)}deg) rotateY(${(
        x * 9
      ).toFixed(2)}deg)`;
    });

    card.addEventListener('mouseleave', () => {
      card.style.transform = 'perspective(900px) rotateX(0deg) rotateY(0deg)';
    });
  });
}

function updateSimulatorUI() {
  document.getElementById('wave-number').textContent = String(state.wave);
  document.getElementById('credits').textContent = String(state.credits);
  document.getElementById('base-hp').textContent = String(state.baseHp);
  document.getElementById('wave-progress').style.width = `${state.progress}%`;
}

function runWaveTick() {
  state.progress += 3;

  if (state.progress >= 100) {
    state.progress = 0;
    state.wave += 1;
    state.credits += 90 + state.wave * 12;
    if (state.wave % 3 === 0) state.baseHp = Math.max(10, state.baseHp - 6);
  }

  updateSimulatorUI();
}

function startSimulation() {
  if (state.running) return;
  state.running = true;
  simInterval = setInterval(runWaveTick, 140);
}

function pauseSimulation() {
  state.running = false;
  clearInterval(simInterval);
}

function resetSimulation() {
  pauseSimulation();
  state.wave = 1;
  state.credits = 450;
  state.baseHp = 100;
  state.progress = 0;
  updateSimulatorUI();
}

function initSimulator() {
  document.getElementById('start-wave').addEventListener('click', startSimulation);
  document.getElementById('pause-wave').addEventListener('click', pauseSimulation);
  document.getElementById('reset-wave').addEventListener('click', resetSimulation);
  updateSimulatorUI();
}

function initTowerTabs() {
  const tabs = document.querySelectorAll('.tower-tab');
  const dpsEl = document.getElementById('tower-dps');
  const rangeEl = document.getElementById('tower-range');
  const rateEl = document.getElementById('tower-rate');
  const noteEl = document.getElementById('tower-note');

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      tabs.forEach(item => item.classList.remove('active'));
      tab.classList.add('active');

      const tower = towerData[tab.dataset.tower];
      dpsEl.textContent = String(tower.dps);
      rangeEl.textContent = String(tower.range);
      rateEl.textContent = String(tower.rate);
      noteEl.textContent = tower.note;
    });
  });
}

function initWorldCycle() {
  const items = [...document.querySelectorAll('.world-item')];
  let index = 0;

  setInterval(() => {
    items[index].classList.remove('active');
    index = (index + 1) % items.length;
    items[index].classList.add('active');
  }, 2200);
}

window.addEventListener('mousemove', e => {
  pointer.x = e.clientX;
  pointer.y = e.clientY;
});

window.addEventListener('resize', () => {
  resizeCanvas();
  createParticles();
});

resizeCanvas();
createParticles();
drawParticles();
setRevealObserver();
initCounters();
initTilt();
initSimulator();
initTowerTabs();
initWorldCycle();
