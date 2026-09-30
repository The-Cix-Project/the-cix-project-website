const menu = document.querySelector('.menu-button');
const nav = document.querySelector('#site-nav');
if (menu && nav) {
  menu.addEventListener('click', () => {
    const open = menu.getAttribute('aria-expanded') === 'true';
    menu.setAttribute('aria-expanded', String(!open));
    nav.classList.toggle('is-open', !open);
  });
}

const notes = {
  cix: ['The operating system', '— the place where the project’s principles become an operator’s reality.'],
  cbs: ['The build boundary', '— where reviewed definitions become deterministic, verifiable package artefacts.'],
  recipes: ['The reviewable input', '— versioned definitions that keep every published artefact explainable.'],
  cache: ['The distribution edge', '— useful bytes delivered without becoming a catalogue or a trust boundary.']
};
document.querySelectorAll('.repo-card').forEach((card) => {
  card.addEventListener('mouseenter', () => {
    const note = notes[card.dataset.repo];
    document.querySelector('#map-title').textContent = note[0];
    document.querySelector('#map-copy').textContent = note[1];
  });
});
