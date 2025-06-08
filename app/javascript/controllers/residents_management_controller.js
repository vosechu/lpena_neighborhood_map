import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "searchInput", "allResidentsBtn", "orphanedBtn", "loadingState", 
    "emptyState", "residentsList", "modal", "modalTitle", "residentForm", 
    "houseSelect", "auditModal", "auditLoadingState", "auditEmptyState", "auditList"
  ]

  connect() {
    this.currentFilter = 'all'
    this.currentSearch = ''
    this.editingResident = null
    this.residents = []
    this.houses = []
    
    this.loadHouses()
    this.loadResidents()
    this.updateActiveButton()
  }

  async loadHouses() {
    try {
      const response = await fetch('/api/houses')
      const houses = await response.json()
      this.houses = houses
      this.populateHouseSelect()
    } catch (error) {
      console.error('Failed to load houses:', error)
    }
  }

  populateHouseSelect() {
    const select = this.houseSelectTarget
    // Clear existing options except the first one
    while (select.children.length > 1) {
      select.removeChild(select.lastChild)
    }
    
    this.houses.forEach(house => {
      const option = document.createElement('option')
      option.value = house.id
      option.textContent = `${house.street_number} ${house.street_name}`
      select.appendChild(option)
    })
  }

  async loadResidents() {
    this.showLoading()
    
    try {
      const params = new URLSearchParams()
      if (this.currentFilter === 'orphaned') {
        params.append('orphaned', 'true')
      }
      if (this.currentSearch) {
        params.append('search', this.currentSearch)
      }
      
      const response = await fetch(`/api/residents?${params}`)
      this.residents = await response.json()
      this.renderResidents()
    } catch (error) {
      console.error('Failed to load residents:', error)
      this.showError('Failed to load residents')
    }
  }

  showLoading() {
    this.loadingStateTarget.classList.remove('hidden')
    this.emptyStateTarget.classList.add('hidden')
    this.residentsListTarget.innerHTML = ''
  }

  hideLoading() {
    this.loadingStateTarget.classList.add('hidden')
  }

  showEmpty() {
    this.emptyStateTarget.classList.remove('hidden')
    this.residentsListTarget.innerHTML = ''
  }

  hideEmpty() {
    this.emptyStateTarget.classList.add('hidden')
  }

  renderResidents() {
    this.hideLoading()
    
    if (this.residents.length === 0) {
      this.showEmpty()
      return
    }
    
    this.hideEmpty()
    
    this.residentsListTarget.innerHTML = this.residents.map(resident => this.residentTemplate(resident)).join('')
  }

  residentTemplate(resident) {
    const house = resident.house ? `${resident.house.address}` : 'No house assigned'
    const displayName = resident.display_name || resident.official_name
    const email = resident.email || 'No email'
    const phone = resident.phone || 'No phone'
    
    return `
      <li class="px-6 py-4">
        <div class="flex items-center justify-between">
          <div class="flex-1">
            <div class="flex items-center">
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-gray-900 truncate">
                  ${this.escapeHtml(displayName)}
                  ${resident.display_name && resident.display_name !== resident.official_name ? 
                    `<span class="text-xs text-gray-500">(${this.escapeHtml(resident.official_name)})</span>` : ''}
                </p>
                <p class="text-sm text-gray-500 truncate">${this.escapeHtml(house)}</p>
                <div class="flex space-x-4 text-xs text-gray-400 mt-1">
                  <span>${this.escapeHtml(email)}</span>
                  <span>${this.escapeHtml(phone)}</span>
                  ${resident.skills ? `<span>Skills: ${this.escapeHtml(resident.skills.substring(0, 50))}${resident.skills.length > 50 ? '...' : ''}</span>` : ''}
                </div>
              </div>
            </div>
          </div>
          <div class="flex items-center space-x-2">
            <button data-action="click->residents-management#viewAuditHistory" 
                    data-resident-id="${resident.id}"
                    class="inline-flex items-center px-3 py-1 border border-gray-300 shadow-sm text-xs leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
              History
            </button>
            <button data-action="click->residents-management#editResident" 
                    data-resident-id="${resident.id}"
                    class="inline-flex items-center px-3 py-1 border border-gray-300 shadow-sm text-xs leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
              Edit
            </button>
            ${this.canDeleteResident(resident) ? `
              <button data-action="click->residents-management#deleteResident" 
                      data-resident-id="${resident.id}"
                      class="inline-flex items-center px-3 py-1 border border-red-300 shadow-sm text-xs leading-4 font-medium rounded-md text-red-700 bg-white hover:bg-red-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500">
                Delete
              </button>
            ` : `
              <button data-action="click->residents-management#hideResident" 
                      data-resident-id="${resident.id}"
                      class="inline-flex items-center px-3 py-1 border border-yellow-300 shadow-sm text-xs leading-4 font-medium rounded-md text-yellow-700 bg-white hover:bg-yellow-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-yellow-500">
                Hide
              </button>
            `}
          </div>
        </div>
      </li>
    `
  }

  canDeleteResident(resident) {
    // Can only delete residents that weren't imported (no last_import_at)
    return !resident.last_import_at
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  search() {
    this.currentSearch = this.searchInputTarget.value
    this.debounce(() => this.loadResidents(), 300)
  }

  debounce(func, wait) {
    clearTimeout(this.debounceTimeout)
    this.debounceTimeout = setTimeout(func, wait)
  }

  showAllResidents() {
    this.currentFilter = 'all'
    this.updateActiveButton()
    this.loadResidents()
  }

  showOrphanedResidents() {
    this.currentFilter = 'orphaned'
    this.updateActiveButton()
    this.loadResidents()
  }

  updateActiveButton() {
    // Remove active state from all buttons
    this.allResidentsBtnTarget.classList.remove('bg-blue-100', 'text-blue-700')
    this.orphanedBtnTarget.classList.remove('bg-blue-100', 'text-blue-700')
    
    // Add active state to current button
    const activeBtn = this.currentFilter === 'all' ? this.allResidentsBtnTarget : this.orphanedBtnTarget
    activeBtn.classList.add('bg-blue-100', 'text-blue-700')
  }

  showAddResidentModal() {
    this.editingResident = null
    this.modalTitleTarget.textContent = 'Add New Resident'
    this.residentFormTarget.reset()
    this.showModal()
  }

  async editResident(event) {
    const residentId = event.target.dataset.residentId
    
    try {
      const response = await fetch(`/api/residents/${residentId}`)
      this.editingResident = await response.json()
      
      this.modalTitleTarget.textContent = 'Edit Resident'
      this.populateForm(this.editingResident)
      this.showModal()
    } catch (error) {
      console.error('Failed to load resident:', error)
      this.showError('Failed to load resident details')
    }
  }

  async viewAuditHistory(event) {
    const residentId = event.target.dataset.residentId
    
    this.showAuditModal()
    this.showAuditLoading()
    
    try {
      const response = await fetch(`/api/audit_logs?model_type=Resident&model_id=${residentId}`)
      const auditLogs = await response.json()
      this.renderAuditHistory(auditLogs)
    } catch (error) {
      console.error('Failed to load audit history:', error)
      this.showAuditError()
    }
  }

  showAuditModal() {
    this.auditModalTarget.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
  }

  closeAuditModal() {
    this.auditModalTarget.classList.add('hidden')
    document.body.classList.remove('overflow-hidden')
  }

  showAuditLoading() {
    this.auditLoadingStateTarget.classList.remove('hidden')
    this.auditEmptyStateTarget.classList.add('hidden')
    this.auditListTarget.innerHTML = ''
  }

  hideAuditLoading() {
    this.auditLoadingStateTarget.classList.add('hidden')
  }

  showAuditEmpty() {
    this.auditEmptyStateTarget.classList.remove('hidden')
  }

  showAuditError() {
    this.hideAuditLoading()
    this.auditListTarget.innerHTML = '<p class="text-red-500 text-sm">Failed to load audit history</p>'
  }

  renderAuditHistory(auditLogs) {
    this.hideAuditLoading()
    
    if (auditLogs.length === 0) {
      this.showAuditEmpty()
      return
    }
    
    this.auditListTarget.innerHTML = auditLogs.map(log => this.auditLogTemplate(log)).join('')
  }

  auditLogTemplate(log) {
    const actionColor = {
      'create': 'text-green-600 bg-green-50',
      'update': 'text-blue-600 bg-blue-50',
      'destroy': 'text-red-600 bg-red-50',
      'hide': 'text-yellow-600 bg-yellow-50'
    }[log.action] || 'text-gray-600 bg-gray-50'

    const changes = this.formatChanges(log.changes)
    const date = new Date(log.created_at).toLocaleString()

    return `
      <div class="border border-gray-200 rounded-lg p-4">
        <div class="flex items-center justify-between mb-2">
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${actionColor}">
            ${log.action.charAt(0).toUpperCase() + log.action.slice(1)}
          </span>
          <span class="text-xs text-gray-500">${date}</span>
        </div>
        <p class="text-sm text-gray-700 mb-2">By: ${log.user_name}</p>
        ${changes ? `<div class="text-xs text-gray-600">${changes}</div>` : ''}
      </div>
    `
  }

  formatChanges(changes) {
    if (!changes || Object.keys(changes).length === 0) {
      return ''
    }

    if (changes.new_values) {
      return 'New record created'
    }

    if (changes.old_values) {
      return 'Record deleted'
    }

    if (changes.hidden_at) {
      return 'Record hidden'
    }

    const changesList = Object.keys(changes).map(key => {
      const change = changes[key]
      if (change.old !== undefined && change.new !== undefined) {
        return `${key}: "${change.old}" → "${change.new}"`
      }
      return `${key}: ${JSON.stringify(change)}`
    })

    return changesList.join('<br>')
  }

  populateForm(resident) {
    const form = this.residentFormTarget
    Object.keys(resident).forEach(key => {
      const input = form.querySelector(`[name="${key}"]`)
      if (input) {
        if (input.type === 'checkbox') {
          input.checked = resident[key]
        } else {
          input.value = resident[key] || ''
        }
      }
    })
  }

  async saveResident(event) {
    event.preventDefault()
    
    const formData = new FormData(this.residentFormTarget)
    const data = {}
    
    // Convert FormData to regular object
    for (let [key, value] of formData.entries()) {
      if (key.startsWith('hide_')) {
        data[key] = true  // Checkbox was checked
      } else {
        data[key] = value
      }
    }
    
    // Add unchecked checkboxes as false
    ['hide_display_name', 'hide_email', 'hide_phone', 'hide_birthdate'].forEach(field => {
      if (!data[field]) {
        data[field] = false
      }
    })
    
    try {
      let response
      if (this.editingResident) {
        response = await fetch(`/api/residents/${this.editingResident.id}`, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': this.getCSRFToken()
          },
          body: JSON.stringify({ resident: data })
        })
      } else {
        response = await fetch('/api/residents', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': this.getCSRFToken()
          },
          body: JSON.stringify({ resident: data })
        })
      }
      
      if (response.ok) {
        this.closeModal()
        this.loadResidents()
        this.showSuccess(this.editingResident ? 'Resident updated successfully' : 'Resident created successfully')
      } else {
        const error = await response.json()
        this.showError(error.errors ? error.errors.join(', ') : 'Failed to save resident')
      }
    } catch (error) {
      console.error('Failed to save resident:', error)
      this.showError('Failed to save resident')
    }
  }

  async deleteResident(event) {
    const residentId = event.target.dataset.residentId
    
    if (!confirm('Are you sure you want to delete this resident? This action cannot be undone.')) {
      return
    }
    
    try {
      const response = await fetch(`/api/residents/${residentId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      if (response.ok) {
        this.loadResidents()
        this.showSuccess('Resident deleted successfully')
      } else {
        const error = await response.json()
        this.showError(error.error || 'Failed to delete resident')
      }
    } catch (error) {
      console.error('Failed to delete resident:', error)
      this.showError('Failed to delete resident')
    }
  }

  async hideResident(event) {
    const residentId = event.target.dataset.residentId
    
    if (!confirm('Are you sure you want to hide this resident? They will no longer appear in listings but can be restored from the admin interface.')) {
      return
    }
    
    try {
      const response = await fetch(`/api/residents/${residentId}/hide`, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      if (response.ok) {
        this.loadResidents()
        this.showSuccess('Resident hidden successfully')
      } else {
        this.showError('Failed to hide resident')
      }
    } catch (error) {
      console.error('Failed to hide resident:', error)
      this.showError('Failed to hide resident')
    }
  }

  showModal() {
    this.modalTarget.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
  }

  closeModal() {
    this.modalTarget.classList.add('hidden')
    document.body.classList.remove('overflow-hidden')
    this.editingResident = null
  }

  getCSRFToken() {
    return document.querySelector('[name="csrf-token"]').content
  }

  showSuccess(message) {
    // Simple success notification - could be enhanced with a proper toast system
    alert(message)
  }

  showError(message) {
    // Simple error notification - could be enhanced with a proper toast system
    alert('Error: ' + message)
  }
}