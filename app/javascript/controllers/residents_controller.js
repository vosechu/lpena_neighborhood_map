import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "searchInput",
    "subscriptionFilter", 
    "newResidentsFilter",
    "loadingIndicator",
    "residentsList",
    "residentsTableBody",
    "noResults",
    "resultsCount",
    "residentRowTemplate"
  ]

  connect() {
    this.searchTimeout = null
    this.loadResidents()
  }

  disconnect() {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
  }

  performSearch() {
    // Debounce search input
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
    
    this.searchTimeout = setTimeout(() => {
      this.loadResidents()
    }, 300)
  }

  applyFilters() {
    this.loadResidents()
  }

  clearFilters() {
    this.searchInputTarget.value = ""
    this.subscriptionFilterTarget.value = ""
    this.newResidentsFilterTarget.value = ""
    this.loadResidents()
  }

  async loadResidents() {
    try {
      this.showLoading()
      
      const params = new URLSearchParams()
      
      // Add search parameter
      const searchValue = this.searchInputTarget.value.trim()
      if (searchValue) {
        params.append('search', searchValue)
      }
      
      // Add subscription filter
      const subscriptionValue = this.subscriptionFilterTarget.value
      if (subscriptionValue) {
        params.append('subscribed', subscriptionValue)
      }
      
      // Add new residents filter
      const newResidentsValue = this.newResidentsFilterTarget.value
      if (newResidentsValue) {
        params.append('new_residents', newResidentsValue)
      }

      const response = await fetch(`/api/residents?${params}`)
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const residents = await response.json()
      this.renderResidents(residents)
      
    } catch (error) {
      console.error('Error loading residents:', error)
      this.showError()
    }
  }

  showLoading() {
    this.loadingIndicatorTarget.classList.remove('hidden')
    this.residentsListTarget.classList.add('hidden')
    this.noResultsTarget.classList.add('hidden')
  }

  showError() {
    this.loadingIndicatorTarget.classList.add('hidden')
    this.residentsListTarget.classList.add('hidden')
    this.noResultsTarget.classList.remove('hidden')
    this.resultsCountTarget.textContent = "Error loading residents"
  }

  renderResidents(residents) {
    this.loadingIndicatorTarget.classList.add('hidden')
    
    if (residents.length === 0) {
      this.residentsListTarget.classList.add('hidden')
      this.noResultsTarget.classList.remove('hidden')
      this.resultsCountTarget.textContent = "No residents found"
      return
    }

    this.noResultsTarget.classList.add('hidden')
    this.residentsListTarget.classList.remove('hidden')
    
    // Clear existing rows
    this.residentsTableBodyTarget.innerHTML = ''
    
    // Add each resident
    residents.forEach(resident => {
      const row = this.createResidentRow(resident)
      this.residentsTableBodyTarget.appendChild(row)
    })
    
    // Update results count
    const count = residents.length
    this.resultsCountTarget.textContent = `Showing ${count} resident${count === 1 ? '' : 's'}`
  }

  createResidentRow(resident) {
    const template = this.residentRowTemplateTarget.content.cloneNode(true)
    const row = template.querySelector('tr')
    
    // Populate name
    const displayNameEl = row.querySelector('[data-field="display_name"]')
    const officialNameEl = row.querySelector('[data-field="official_name"]')
    displayNameEl.textContent = resident.display_name || resident.official_name
    officialNameEl.textContent = resident.official_name
    
    // Populate address (we need to fetch house info)
    const addressEl = row.querySelector('[data-field="address"]')
    addressEl.textContent = resident.house ? resident.house.address : 'Address not available'
    
    // Populate contact info
    const emailEl = row.querySelector('[data-field="email"]')
    const phoneEl = row.querySelector('[data-field="phone"]')
    emailEl.textContent = resident.email || ''
    phoneEl.textContent = resident.phone || ''
    
    // Populate subscription badge
    const subscriptionBadgeEl = row.querySelector('[data-field="subscription_badge"]')
    if (resident.subscribed) {
      subscriptionBadgeEl.textContent = 'Subscribed'
      subscriptionBadgeEl.className = 'inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800'
    } else {
      subscriptionBadgeEl.textContent = 'Not Subscribed'
      subscriptionBadgeEl.className = 'inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-800'
    }
    
    // Populate status badge
    const statusBadgeEl = row.querySelector('[data-field="status_badge"]')
    if (resident.is_new) {
      statusBadgeEl.textContent = 'New'
      statusBadgeEl.className = 'inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800'
    } else {
      statusBadgeEl.textContent = 'Current'
      statusBadgeEl.className = 'inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-800'
    }
    
    // Set up action buttons
    const editButton = row.querySelector('[data-field="edit_button"]')
    const viewButton = row.querySelector('[data-field="view_button"]')
    
    editButton.addEventListener('click', () => this.editResident(resident))
    viewButton.addEventListener('click', () => this.viewResident(resident))
    
    return row
  }

  editResident(resident) {
    // TODO: Implement edit functionality
    console.log('Edit resident:', resident)
  }

  viewResident(resident) {
    // TODO: Implement view functionality
    console.log('View resident:', resident)
  }
}