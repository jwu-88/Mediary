document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.chip-row').forEach((row) => {
    row.addEventListener('click', (event) => {
      const chip = event.target.closest('button.chip');
      if (!chip) return;
      row.querySelectorAll('button.chip').forEach((item) => item.classList.remove('active'));
      chip.classList.add('active');
    });
  });

  const calendar = document.querySelector('.calendar-grid');
  calendar?.addEventListener('click', (event) => {
    const day = event.target.closest('button.day:not(.muted)');
    if (!day) return;
    calendar.querySelectorAll('.day').forEach((item) => item.classList.remove('selected'));
    day.classList.add('selected');
  });

  const search = document.querySelector('.search-input');
  search?.addEventListener('input', () => {
    const query = search.value.trim().toLowerCase();
    document.querySelectorAll('.med-row').forEach((row) => {
      row.hidden = !row.textContent.toLowerCase().includes(query);
    });
  });

  const capture = document.querySelector('[data-action="capture"]');
  const scanTip = document.querySelector('#scan-tip');
  capture?.addEventListener('click', () => {
    capture.setAttribute('aria-busy', 'true');
    if (scanTip) scanTip.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Analyzing label…';
    window.setTimeout(() => {
      capture.removeAttribute('aria-busy');
      if (scanTip) scanTip.innerHTML = '<i class="fa-solid fa-circle-check"></i> Medication found';
    }, 1200);
  });

  document.querySelectorAll('[data-action="add-calendar"]').forEach((button) => {
    button.addEventListener('click', () => {
      button.innerHTML = '<i class="fa-solid fa-circle-check"></i> Added to calendar';
      button.disabled = true;
    });
  });
});
