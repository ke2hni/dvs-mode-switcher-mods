document.addEventListener('DOMContentLoaded', function() {
    const themeToggle = document.getElementById('theme-toggle');
    const isDarkMode = localStorage.getItem('darkMode') === 'true';

    if (isDarkMode) {
        document.body.classList.add('dark-mode');
        themeToggle.innerText = 'Light Mode';
    }

    themeToggle.addEventListener('click', function() {
        document.body.classList.toggle('dark-mode');
        if (document.body.classList.contains('dark-mode')) {
            localStorage.setItem('darkMode', 'true');
            themeToggle.innerText = 'Light Mode';
        } else {
            localStorage.setItem('darkMode', 'false');
            themeToggle.innerText = 'Dark Mode';
        }
    });
});