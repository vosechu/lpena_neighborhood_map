# Pin npm packages by running ./bin/importmap

pin 'application'
pin '@hotwired/stimulus', to: 'stimulus.min.js'
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js'
pin_all_from 'app/javascript/controllers', under: 'controllers'
pin 'leaflet', to: 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'
pin 'lodash', to: 'https://cdn.jsdelivr.net/npm/lodash@4.17.21/lodash.min.js'
