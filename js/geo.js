// MyGeekPC Geo-Targeting
// Shows relevant service area based on visitor location

(function() {
    // Configuration
    const CONFIG = {
        riverside: {
            badge: 'On-Site: Idyllwild & Pine Cove · Remote: Nationwide',
            onSite: true,
            areaName: 'Idyllwild & Pine Cove'
        },
        sandiego: {
            badge: 'On-Site: San Diego · Remote: Nationwide',
            onSite: true,
            areaName: 'San Diego'
        },
        default: {
            badge: 'Remote Support · Nationwide',
            onSite: false,
            areaName: null
        }
    };

    // Detect region from IP
    async function detectRegion() {
        try {
            const response = await fetch('https://ipapi.co/json/');
            const data = await response.json();
            
            const city = (data.city || '').toLowerCase();
            const region = (data.region || '').toLowerCase();
            
            // Riverside County cities
            const riversideCities = ['idyllwild', 'pine cove', 'hemet', 'san jacinto', 'banning', 'beaumont', 'palm springs', 'palm desert', 'riverside', 'corona', 'temecula', 'murrieta', 'mountain center', 'anza'];
            
            // San Diego County cities  
            const sandiegoCities = ['san diego', 'la jolla', 'del mar', 'encinitas', 'carlsbad', 'oceanside', 'escondido', 'poway', 'el cajon', 'chula vista', 'national city', 'coronado', 'santee', 'la mesa'];
            
            if (region === 'california') {
                if (riversideCities.some(c => city.includes(c))) {
                    return 'riverside';
                }
                if (sandiegoCities.some(c => city.includes(c))) {
                    return 'sandiego';
                }
            }
            
            return 'default';
        } catch (error) {
            console.log('Geo detection unavailable:', error);
            return 'default';
        }
    }

    // Update page content based on region
    function updateContent(region) {
        const config = CONFIG[region];
        
        // Update hero badge
        const heroBadge = document.querySelector('.hero-label');
        if (heroBadge) {
            heroBadge.textContent = config.badge;
        }
        
        // Show/hide geo-specific elements
        document.querySelectorAll('[data-geo-riverside]').forEach(el => {
            el.style.display = region === 'riverside' ? '' : 'none';
        });
        
        document.querySelectorAll('[data-geo-sandiego]').forEach(el => {
            el.style.display = region === 'sandiego' ? '' : 'none';
        });
        
        document.querySelectorAll('[data-geo-remote]').forEach(el => {
            el.style.display = region === 'default' ? '' : 'none';
        });
        
        document.querySelectorAll('[data-geo-local]').forEach(el => {
            el.style.display = config.onSite ? '' : 'none';
        });
        
        // Add class to body
        document.body.classList.add('geo-' + region);
    }

    // Run on page load
    async function init() {
        const region = await detectRegion();
        updateContent(region);
    }
    
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
