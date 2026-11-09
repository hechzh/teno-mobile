let language = navigator.language.startsWith('zh') ? 'zh' : 'en';
    try { const saved = localStorage.getItem('teno.web.interface-locale'); if (saved === 'zh' || saved === 'en') language = saved; } catch (_) {}
    document.documentElement.lang = language === 'zh' ? 'zh-Hans' : 'en';
    if (language === 'zh') document.querySelector('#loading p').textContent = '正在打开你的工作空间…';
