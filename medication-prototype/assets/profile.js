document.addEventListener('DOMContentLoaded', () => {
  const screen = document.querySelector('[data-profile-screen]');
  if (!screen) return;

  const editButton = document.querySelector('#profile-edit');
  const cancelButton = document.querySelector('#profile-cancel');
  const doneButton = document.querySelector('#profile-done');
  const headerSpacer = document.querySelector('#profile-header-spacer');
  const modeLabel = document.querySelector('#profile-mode-label');
  const announcer = document.querySelector('#profile-announcer');
  const avatarEditor = document.querySelector('#avatar-editor');
  const avatarInput = document.querySelector('#avatar-input');
  const profilePhoto = document.querySelector('#profile-photo');
  const nameInput = document.querySelector('#profile-name');
  const emailInput = document.querySelector('#profile-email');
  const bloodTypeInput = document.querySelector('#blood-type');
  const careTeamInput = document.querySelector('#care-team');
  const allergyTokens = document.querySelector('#allergy-tokens');
  const allergyAdd = document.querySelector('#allergy-add');
  const allergyInput = document.querySelector('#allergy-input');
  const reminders = document.querySelector('#dose-reminders');
  const reminderStatus = document.querySelector('#reminder-status');
  const discardDialog = document.querySelector('#discard-dialog');
  const keepEditing = document.querySelector('#keep-editing');
  const discardChanges = document.querySelector('#discard-changes');
  const editableFields = [nameInput, emailInput, careTeamInput];
  let savedSnapshot = null;

  const announce = (message) => {
    announcer.textContent = '';
    window.setTimeout(() => { announcer.textContent = message; }, 20);
  };

  const allergyValues = () => Array.from(allergyTokens.querySelectorAll('[data-allergy]'))
    .map((token) => token.dataset.allergy);

  const currentDraft = () => ({
    name: nameInput.value,
    email: emailInput.value,
    bloodType: bloodTypeInput.value,
    allergies: allergyValues(),
    careTeam: careTeamInput.value,
    avatar: profilePhoto.src,
  });

  const isDirty = () => savedSnapshot && JSON.stringify(currentDraft()) !== JSON.stringify(savedSnapshot);

  const createAllergyToken = (allergy) => {
    const button = document.createElement('button');
    button.className = 'allergy-token';
    button.type = 'button';
    button.dataset.allergy = allergy;
    button.setAttribute('aria-label', `Remove ${allergy} allergy`);
    button.append(document.createTextNode(`${allergy} `));
    const icon = document.createElement('i');
    icon.className = 'fa-solid fa-xmark';
    icon.setAttribute('aria-hidden', 'true');
    button.append(icon);
    return button;
  };

  const renderAllergies = (allergies) => {
    allergyTokens.replaceChildren(...allergies.map(createAllergyToken));
  };

  const clearValidation = () => {
    editableFields.forEach((field) => {
      field.removeAttribute('aria-invalid');
      document.querySelector(`#${field.id}-error`).textContent = '';
    });
  };

  const validateField = (field) => {
    const value = field.value.trim();
    let message = '';
    if (field === nameInput && value.length < 2) message = 'Enter your full name.';
    if (field === emailInput && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) message = 'Enter a valid email address.';
    if (field === careTeamInput && value.length < 2) message = 'Enter a care team or provider.';
    if (message) field.setAttribute('aria-invalid', 'true');
    else field.removeAttribute('aria-invalid');
    document.querySelector(`#${field.id}-error`).textContent = message;
    return !message;
  };

  const setMode = (editing, { focusFirst = true } = {}) => {
    screen.dataset.mode = editing ? 'edit' : 'read';
    document.querySelectorAll('[data-edit-only]').forEach((element) => { element.hidden = !editing; });
    document.querySelectorAll('[data-read-only]').forEach((element) => { element.hidden = editing; });
    editButton.hidden = editing;
    doneButton.hidden = !editing;
    cancelButton.hidden = !editing;
    headerSpacer.hidden = editing;
    modeLabel.textContent = editing ? 'Editing' : 'Account';
    avatarEditor.disabled = !editing;
    document.querySelectorAll('[data-lock-during-edit]').forEach((element) => {
      element.disabled = editing;
      element.setAttribute('aria-disabled', String(editing));
    });
    if (editing && focusFirst) window.requestAnimationFrame(() => nameInput.focus());
  };

  const restoreSnapshot = () => {
    if (!savedSnapshot) return;
    nameInput.value = savedSnapshot.name;
    emailInput.value = savedSnapshot.email;
    bloodTypeInput.value = savedSnapshot.bloodType;
    careTeamInput.value = savedSnapshot.careTeam;
    profilePhoto.src = savedSnapshot.avatar;
    renderAllergies(savedSnapshot.allergies);
    avatarInput.value = '';
    allergyInput.value = '';
    allergyInput.hidden = true;
    clearValidation();
  };

  const exitWithoutSaving = () => {
    restoreSnapshot();
    setMode(false, { focusFirst: false });
    announce('Editing cancelled.');
    editButton.focus();
  };

  editButton.addEventListener('click', () => {
    savedSnapshot = currentDraft();
    clearValidation();
    setMode(true);
    announce('Profile editing mode. Name field focused.');
  });

  editableFields.forEach((field) => field.addEventListener('blur', () => validateField(field)));

  doneButton.addEventListener('click', () => {
    const results = editableFields.map(validateField);
    if (results.includes(false)) {
      announce('Profile could not be saved. Check the highlighted fields. Your changes are preserved.');
      editableFields.find((field) => field.getAttribute('aria-invalid') === 'true')?.focus();
      return;
    }

    document.querySelector('#profile-name-read').textContent = nameInput.value.trim();
    document.querySelector('#profile-email-read').textContent = emailInput.value.trim();
    document.querySelector('#blood-type-read').textContent = bloodTypeInput.value;
    document.querySelector('#allergies-read').textContent = allergyValues().join(', ') || 'None recorded';
    document.querySelector('#care-team-read').textContent = careTeamInput.value.trim();
    savedSnapshot = currentDraft();
    setMode(false, { focusFirst: false });
    announce('Profile saved.');
    editButton.focus();
  });

  cancelButton.addEventListener('click', () => {
    if (!isDirty()) {
      setMode(false, { focusFirst: false });
      announce('Editing cancelled.');
      editButton.focus();
      return;
    }
    if (typeof discardDialog.showModal === 'function') {
      discardDialog.showModal();
      keepEditing.focus();
    } else if (window.confirm('Discard changes?')) {
      exitWithoutSaving();
    }
  });

  keepEditing.addEventListener('click', () => {
    discardDialog.close();
    cancelButton.focus();
  });

  discardChanges.addEventListener('click', () => {
    discardDialog.close();
    exitWithoutSaving();
  });

  discardDialog.addEventListener('cancel', (event) => {
    event.preventDefault();
    discardDialog.close();
    cancelButton.focus();
  });

  avatarEditor.addEventListener('click', () => avatarInput.click());
  avatarInput.addEventListener('change', () => {
    const [file] = avatarInput.files;
    if (!file) return;
    const reader = new FileReader();
    reader.addEventListener('load', () => { profilePhoto.src = reader.result; });
    reader.readAsDataURL(file);
  });

  allergyTokens.addEventListener('click', (event) => {
    const token = event.target.closest('[data-allergy]');
    if (token && screen.dataset.mode === 'edit') token.remove();
  });

  allergyAdd.addEventListener('click', () => {
    allergyInput.hidden = false;
    allergyInput.focus();
  });

  allergyInput.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
      allergyInput.value = '';
      allergyInput.hidden = true;
      allergyAdd.focus();
      return;
    }
    if (event.key !== 'Enter') return;
    event.preventDefault();
    const allergy = allergyInput.value.trim();
    if (allergy && !allergyValues().some((item) => item.toLowerCase() === allergy.toLowerCase())) {
      allergyTokens.append(createAllergyToken(allergy));
    }
    allergyInput.value = '';
    allergyInput.hidden = true;
    allergyAdd.focus();
  });

  reminders.addEventListener('change', () => {
    reminderStatus.textContent = reminders.checked ? 'On' : 'Off';
    announce(`Dose reminders turned ${reminders.checked ? 'on' : 'off'}.`);
  });

  setMode(false, { focusFirst: false });
});
