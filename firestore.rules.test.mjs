import { after, before, describe, it } from 'node:test';
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
    bloodType: 'O+',
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

  it('rejects historical deletes but permits unsaving a library medication', async () => {
    const owner = testEnvironment.authenticatedContext('owner').firestore();
    await assertFails(deleteDoc(doc(owner, 'users/owner')));
    await assertFails(
      deleteDoc(doc(owner, 'users/owner/medications/medication-1')),
    );
    await assertFails(
      deleteDoc(doc(owner, 'users/owner/doseLogs/dose-1')),
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
});
