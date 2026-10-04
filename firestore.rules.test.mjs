import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  deleteDoc,
  doc,
  getDoc,
  setDoc,
} from 'firebase/firestore';

const projectId = 'cacapp-3a771';
const here = path.dirname(fileURLToPath(import.meta.url));
let testEnvironment;

const timestamp = Timestamp.fromDate(new Date('2026-01-01T12:00:00.000Z'));

function validUser() {
  return {
    email: 'owner@example.com',
    displayName: 'Owner',
    bloodType: '',
    photoUrl: '',
    allergies: ['Penicillin'],
    careTeam: 'City Health',
    createdAt: timestamp,
    updatedAt: timestamp,
    timezone: 'America/New_York',
    preferences: {
      theme: 'system',
      accentColor: 'blue',
      doseNotifications: true,
      followUpAlerts: true,
      reminderSound: 'Gentle Chime',
      language: 'English',
      units: 'Metric',
      timeFormat: '12-hour',
    },
  };
}

function validMedication() {
  return {
    name: 'Amoxicillin',
    genericName: 'Amoxicillin',
    strength: '500 mg',
    form: 'Capsule',
    route: 'Oral',
    instructions: 'Take with water',
    prescriber: 'City Health',
    pharmacy: 'Mediary Pharmacy',
    notes: '',
    active: true,
    source: 'manual',
    createdAt: timestamp,
    updatedAt: timestamp,
  };
}

function validDoseLog() {
  return {
    medicationId: 'medication-1',
    scheduleId: 'schedule-1',
    scheduledFor: timestamp,
    localDate: '2026-01-01',
    localTime: '08:00',
    status: 'due',
    notes: '',
    createdAt: timestamp,
    updatedAt: timestamp,
  };
}

function validSchedule() {
  return {
    medicationId: 'medication-1',
    doseAmount: 1,
    doseUnit: 'tablet',
    times: ['08:00:00'],
    frequency: 'weekly',
    daysOfWeek: [1, 3, 5],
    startDate: '2026-01-01',
    endDate: '2026-12-31',
    timezone: 'America/New_York',
    instructions: '',
    active: true,
    createdAt: timestamp,
    updatedAt: timestamp,
  };
}

describe('Firestore security rules', () => {
  before(async () => {
    testEnvironment = await initializeTestEnvironment({
      projectId,
      firestore: {
        rules: await fs.readFile(path.join(here, 'firestore.rules'), 'utf8'),
      },
    });
  });

  after(async () => {
    await testEnvironment.cleanup();
  });

  it('allows an owner to create and read a valid profile and medication', async () => {
    const owner = testEnvironment.authenticatedContext('owner').firestore();
    await assertSucceeds(setDoc(doc(owner, 'users/owner'), validUser()));
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner/medications/medication-1'), validMedication()),
    );
    await assertSucceeds(getDoc(doc(owner, 'users/owner')));
  });

  it('rejects impossible dates, malformed times and unknown timezones', async () => {
    const owner = testEnvironment.authenticatedContext('owner').firestore();
    for (const invalid of [
      {times: [null, 123, '99:99']}, {times: ['24:00']},
      {startDate: '2026-02-30'}, {endDate: '1900-01-01'},
      {timezone: 'Moon/Base'}, {doseAmount: Infinity},
    ]) {
      await assertFails(setDoc(doc(owner, 'users/owner/schedules/invalid'), {...validSchedule(), ...invalid}));
    }
    await assertSucceeds(setDoc(doc(owner, 'users/owner/schedules/leap'), {...validSchedule(), startDate: '2028-02-29', endDate: '2028-03-01'}));
  });

  it('rejects another user from reading or writing the owner data', async () => {
    const other = testEnvironment.authenticatedContext('other').firestore();
    await assertFails(getDoc(doc(other, 'users/owner')));
    await assertFails(
      setDoc(
        doc(other, 'users/owner/medications/medication-1'),
        validMedication(),
      ),
    );
  });

  it('allows a valid 24-hour time format preference', async () => {
    const owner = testEnvironment.authenticatedContext('owner').firestore();
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner'), {
        ...validUser(),
        preferences: {
          ...validUser().preferences,
          timeFormat: '24-hour',
        },
      }),
    );
    await assertFails(
      setDoc(doc(owner, 'users/owner'), {
        ...validUser(),
        preferences: {
          ...validUser().preferences,
          timeFormat: '24-hours',
        },
      }),
    );
  });

  it('rejects unknown, image, invalid enum, and invalid type fields', async () => {
    const owner = testEnvironment.authenticatedContext('owner').firestore();
    await assertFails(
      setDoc(doc(owner, 'users/owner/medications/unknown-field'), {
        ...validMedication(),
        unexpected: 'not allowed',
      }),
    );
    await assertFails(
      setDoc(doc(owner, 'users/owner/medications/image-field'), {
        ...validMedication(),
        imageUrl: 'https://example.com/label.png',
      }),
    );
    await assertFails(
      setDoc(doc(owner, 'users/owner/medications/bad-source'), {
        ...validMedication(),
        source: 'photo',
      }),
    );
    await assertFails(
      setDoc(doc(owner, 'users/owner/medications/bad-type'), {
        ...validMedication(),
        active: 'true',
      }),
    );
  });

  it('validates RxNorm catalog metadata while preserving legacy medications', async () => {
    const owner = testEnvironment.authenticatedContext('owner').firestore();
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner/medications/rxnorm-6809'), {
        ...validMedication(),
        catalogId: '6809',
        catalogSource: 'rxnorm',
        catalogVersion: '2026-08-01',
      }),
    );
    await assertFails(
      setDoc(doc(owner, 'users/owner/medications/unknown-catalog'), {
        ...validMedication(),
        catalogId: '6809',
        catalogSource: 'openfda',
        catalogVersion: '2026-08-01',
      }),
    );
    await assertFails(
      setDoc(doc(owner, 'users/owner/medications/empty-catalog-id'), {
        ...validMedication(),
        catalogId: '',
        catalogSource: 'rxnorm',
        catalogVersion: '2026-08-01',
      }),
    );
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner/savedMedications/rxnorm-6809'), {
        savedAt: timestamp,
        libraryVersion: 'current',
        catalogId: '6809',
        catalogSource: 'rxnorm',
        catalogVersion: '2026-08-01',
      }),
    );
    await assertFails(
      setDoc(doc(owner, 'users/owner/savedMedications/unknown-catalog'), {
        savedAt: timestamp,
        libraryVersion: 'current',
        catalogId: '6809',
        catalogSource: 'openfda',
        catalogVersion: '2026-08-01',
      }),
    );
  });

  it('allows an owner to delete one medication regimen and its records', async () => {
    const owner = testEnvironment.authenticatedContext('owner').firestore();
    await assertFails(deleteDoc(doc(owner, 'users/owner')));
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner/medications/medication-delete-1'), {
        ...validMedication(),
      }),
    );
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner/schedules/schedule-delete-1'), {
        ...validSchedule(),
        medicationId: 'medication-delete-1',
      }),
    );
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner/doseLogs/dose-delete-1'), {
        ...validDoseLog(),
        medicationId: 'medication-delete-1',
        scheduleId: 'schedule-delete-1',
      }),
    );
    await assertSucceeds(
      deleteDoc(doc(owner, 'users/owner/medications/medication-delete-1')),
    );
    await assertSucceeds(
      deleteDoc(doc(owner, 'users/owner/schedules/schedule-delete-1')),
    );
    await assertSucceeds(
      deleteDoc(doc(owner, 'users/owner/doseLogs/dose-delete-1')),
    );
    assert.equal(
      (await getDoc(
        doc(owner, 'users/owner/medications/medication-delete-1'),
      )).exists(),
      false,
    );
    assert.equal(
      (await getDoc(
        doc(owner, 'users/owner/schedules/schedule-delete-1'),
      )).exists(),
      false,
    );
    assert.equal(
      (await getDoc(doc(owner, 'users/owner/doseLogs/dose-delete-1'))).exists(),
      false,
    );
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner/savedMedications/medication-1'), {
        savedAt: timestamp,
        libraryVersion: 'current',
      }),
    );
    await assertSucceeds(
      deleteDoc(doc(owner, 'users/owner/savedMedications/medication-1')),
    );
  });

  it('rejects another user from deleting the owner regimen', async () => {
    const other = testEnvironment.authenticatedContext('other').firestore();
    await assertFails(
      deleteDoc(doc(other, 'users/owner/medications/medication-1')),
    );
    await assertFails(
      deleteDoc(doc(other, 'users/owner/schedules/schedule-1')),
    );
    await assertFails(
      deleteDoc(doc(other, 'users/owner/doseLogs/dose-1')),
    );
  });

  it('requires snoozedUntil for snoozed doses', async () => {
    const owner = testEnvironment.authenticatedContext('owner').firestore();
    await assertFails(
      setDoc(doc(owner, 'users/owner/doseLogs/snoozed-without-time'), {
        ...validDoseLog(),
        status: 'snoozed',
      }),
    );
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner/doseLogs/snoozed-with-time'), {
        ...validDoseLog(),
        status: 'snoozed',
        snoozedUntil: timestamp,
      }),
    );
  });

  it('validates recurrence, dates, times, and timezone metadata', async () => {
    const owner = testEnvironment.authenticatedContext('owner').firestore();
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner/schedules/weekly-1'), validSchedule()),
    );
    await assertFails(
      setDoc(doc(owner, 'users/owner/schedules/bad-frequency'), {
        ...validSchedule(),
        frequency: 'monthly',
      }),
    );
    await assertFails(
      setDoc(doc(owner, 'users/owner/schedules/bad-date'), {
        ...validSchedule(),
        startDate: '01/01/2026',
      }),
    );
    await assertFails(
      setDoc(doc(owner, 'users/owner/schedules/bad-timezone'), {
        ...validSchedule(),
        timezone: 'not a timezone',
      }),
    );
    await assertFails(
      setDoc(doc(owner, 'users/owner/doseLogs/bad-time'), {
        ...validDoseLog(),
        localTime: 'tomorrow morning',
      }),
    );
  });

  it('allows archive and cancel updates while preserving historical records', async () => {
    const owner = testEnvironment.authenticatedContext('owner').firestore();
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner/schedules/archive-1'), validSchedule()),
    );
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner/doseLogs/archive-dose'), validDoseLog()),
    );
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner/schedules/archive-1'), {
        ...validSchedule(),
        active: false,
        updatedAt: timestamp,
      }),
    );
    await assertSucceeds(
      setDoc(doc(owner, 'users/owner/doseLogs/archive-dose'), {
        ...validDoseLog(),
        status: 'cancelled',
        updatedAt: timestamp,
      }),
    );
    await assertSucceeds(getDoc(doc(owner, 'users/owner/doseLogs/archive-dose')));
  });
});
