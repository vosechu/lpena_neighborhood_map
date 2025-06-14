// ModalService handles all modal state, form rendering, and validation
export class ModalService {
  constructor(modalElement) {
    if (!modalElement) {
      throw new Error('ModalService requires a modal element to be passed in');
    }
    this.modalElement = modalElement;
  }

  // Check if modal is currently visible
  isVisible() {
    return this.modalElement && this.modalElement.style.display === 'block';
  }

  // Show modal with content
  show(content) {
    if (this.modalElement) {
      this.modalElement.innerHTML = content;
      this.modalElement.style.display = 'block';
    }
  }

  // Hide modal
  hide() {
    if (this.modalElement) {
      this.modalElement.style.display = 'none';
    }
  }

  // Show resident edit modal
  showResidentEditModal(resident, house, currentUserId) {
    const templateHtml = document.getElementById('resident-edit-form-template').innerHTML;
    const canHide = (resident.user_id && parseInt(resident.user_id, 10) === currentUserId);
    const content = _.template(templateHtml)({ resident, canHide });

    this.show(content);
    this.attachResidentFormHandlers(resident, house);
  }

  // Show add resident modal
  showAddResidentModal(house) {
    const templateHtml = document.getElementById('add-resident-form-template').innerHTML;
    const content = _.template(templateHtml)({ house });

    this.show(content);
    this.attachAddResidentFormHandlers(house);
  }

  // Attach event handlers for resident edit form
  attachResidentFormHandlers(resident, house) {
    // Hide field toggles
    this.modalElement.querySelectorAll('.toggle-hide-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const fieldKey = e.currentTarget.dataset.targetField;
        const checkbox = this.modalElement.querySelector(`input[data-resident-field="${fieldKey}"]`);
        const inputFieldKey = fieldKey.replace('hide_', '');
        const input = this.modalElement.querySelector(`[data-resident-field="${inputFieldKey}"]`);

        if (!checkbox) return;

        checkbox.checked = !checkbox.checked;
        if (input) {
          input.disabled = checkbox.checked;
          input.classList.toggle('opacity-50', checkbox.checked);
          input.classList.toggle('cursor-not-allowed', checkbox.checked);
        }

        // Swap icons
        const eye = e.currentTarget.querySelector('.icon-eye');
        const eyeSlash = e.currentTarget.querySelector('.icon-eye-slash');
        if (eye && eyeSlash) {
          if (checkbox.checked) {
            eye.style.display = 'none';
            eyeSlash.style.display = 'inline';
          } else {
            eye.style.display = 'inline';
            eyeSlash.style.display = 'none';
          }
        }
      });
    });

    // Hide all information checkbox handler
    const hideAllCheckbox = this.modalElement.querySelector('#resident-hide-all');
    if (hideAllCheckbox) {
      hideAllCheckbox.addEventListener('change', (e) => {
        const hide = e.target.checked;
        this.modalElement.querySelectorAll('[data-resident-field]').forEach(el => {
          const fieldName = el.dataset.residentField;
          if (fieldName.startsWith('hide_') || fieldName === 'hidden') return;
          if (el.type !== 'checkbox') {
            el.disabled = hide;
            el.classList.toggle('opacity-50', hide);
            el.classList.toggle('cursor-not-allowed', hide);
          }
        });
      });
    }

    // Save button
    const saveBtn = this.modalElement.querySelector('.save-resident-btn');
    if (saveBtn) {
      saveBtn.addEventListener('click', (e) => {
        e.preventDefault();
        const formData = this.collectFormData();
        this.onResidentSave?.(resident, house, formData);
      });
    }

    // Homepage normalization
    const homepageField = this.modalElement.querySelector('#resident-homepage');
    if (homepageField) {
      homepageField.addEventListener('blur', (e) => this.normalizeHomepageUrlField(e.target));
    }

    // Birthdate picker enhancement
    this.enhanceBirthdateField();

    // Enter key submission
    this.modalElement.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        const saveBtn = this.modalElement.querySelector('.save-resident-btn');
        if (saveBtn && !saveBtn.disabled) {
          saveBtn.click();
        }
      }
    });
  }

  // Attach event handlers for add resident form
  attachAddResidentFormHandlers(house) {
    const saveBtn = this.modalElement.querySelector('.add-resident-save-btn');
    if (saveBtn) {
      saveBtn.addEventListener('click', (e) => {
        e.preventDefault();
        const formData = this.collectFormData();

        // Client-side validation
        if (!formData.display_name || formData.display_name.trim() === '') {
          this.showValidationError('Name is required.');
          return;
        }

        // Default official_name if not provided
        if (!formData.official_name) {
          formData.official_name = formData.display_name;
        }

        this.onResidentAdd?.(house, formData);
      });
    }

    const homepageField = this.modalElement.querySelector('#resident-homepage');
    if (homepageField) {
      homepageField.addEventListener('blur', (e) => this.normalizeHomepageUrlField(e.target));
    }

    // Birthdate picker enhancement
    this.enhanceBirthdateField();

    // Enter key submission
    this.modalElement.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        const saveBtn = this.modalElement.querySelector('.add-resident-save-btn');
        if (saveBtn && !saveBtn.disabled) {
          saveBtn.click();
        }
      }
    });
  }

  // Collect form data from modal
  collectFormData() {
    const formData = {};
    const formFields = this.modalElement.querySelectorAll('[data-resident-field]');

    formFields.forEach(field => {
      const fieldName = field.dataset.residentField;
      if (field.type === 'checkbox') {
        formData[fieldName] = field.checked;
      } else {
        formData[fieldName] = field.value;
      }
    });

    return formData;
  }

  // Show validation error
  showValidationError(message) {
    // Simple validation error display - could be enhanced
    alert(message); // TODO: Replace with better UI
  }

  // Normalize homepage URL for input fields (with visual feedback)
  normalizeHomepageUrlField(inputField) {
    let url = inputField.value.trim();

    if (!url) return;

    const lowerUrl = url.toLowerCase();
    if (!lowerUrl.startsWith('http://') && !lowerUrl.startsWith('https://')) {
      url = 'https://' + url;
      inputField.value = url;

      // Visual feedback
      inputField.style.backgroundColor = '#f0f9ff';
      inputField.style.transition = 'background-color 0.3s ease';

      setTimeout(() => {
        inputField.style.backgroundColor = '';
        setTimeout(() => {
          inputField.style.transition = '';
        }, 300);
      }, 1000);
    }
  }

  // Normalize homepage URL string (for API calls)
  normalizeHomepageUrl(url) {
    if (!url || !url.trim()) return url;

    const trimmedUrl = url.trim();
    const lowerUrl = trimmedUrl.toLowerCase();

    if (!lowerUrl.startsWith('http://') && !lowerUrl.startsWith('https://')) {
      return 'https://' + trimmedUrl;
    }

    return trimmedUrl;
  }

  // Enhance birthdate field with date picker
  enhanceBirthdateField() {
    const birthdateField = this.modalElement.querySelector('#resident-birthdate');
    if (!birthdateField) return;

    // Create wrapper div
    const wrapper = document.createElement('div');
    wrapper.className = 'relative';

    birthdateField.parentNode.insertBefore(wrapper, birthdateField);
    wrapper.appendChild(birthdateField);

    // Create hidden date input
    const dateInput = document.createElement('input');
    dateInput.type = 'date';
    dateInput.className = 'absolute right-0 top-0 w-12 h-full opacity-0 cursor-pointer';

    // Set initial value if birthdate exists
    if (birthdateField.value) {
      const mmdd = birthdateField.value;
      const parts = mmdd.split('-');
      if (parts.length === 2) {
        const month = parts[0].padStart(2, '0');
        const day = parts[1].padStart(2, '0');
        const currentYear = new Date().getFullYear();
        dateInput.value = `${currentYear}-${month}-${day}`;
      }
    }

    wrapper.appendChild(dateInput);

    // Create clickable calendar button
    const calendarButton = document.createElement('button');
    calendarButton.type = 'button';
    calendarButton.className = 'absolute right-0 top-0 w-12 h-full flex items-center justify-end pr-3 cursor-pointer';
    calendarButton.style.zIndex = '2';
    calendarButton.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
      </svg>
    `;

    // Add click handler to the button
    calendarButton.addEventListener('click', () => {
      dateInput.showPicker();
    });

    wrapper.appendChild(calendarButton);

    // Style the text input
    birthdateField.style.paddingRight = '2.5rem';

    // Handle date picker changes
    dateInput.addEventListener('change', (e) => {
      const selectedDate = e.target.value;
      if (selectedDate) {
        // Extract month and day directly from the date string (YYYY-MM-DD)
        const [year, month, day] = selectedDate.split('-');
        birthdateField.value = `${month}-${day}`;
        birthdateField.dispatchEvent(new Event('input', { bubbles: true }));
      }
    });

    // Handle manual text input
    birthdateField.addEventListener('input', (e) => {
      const value = e.target.value;
      const mmddPattern = /^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$/;

      if (mmddPattern.test(value)) {
        const parts = value.split('-');
        const month = parts[0];
        const day = parts[1];
        const currentYear = new Date().getFullYear();
        // Just use the date string without time
        dateInput.value = `${currentYear}-${month}-${day}`;
      }
    });
  }

  // Set callback for resident save
  onResidentSave(callback) {
    this.onResidentSave = callback;
  }

  // Set callback for resident add
  onResidentAdd(callback) {
    this.onResidentAdd = callback;
  }
}
