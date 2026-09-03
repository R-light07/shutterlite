/* ════════════════════════════════════════════════════════════
   SHUTTERLITE — Marcação de Sessões Fotográficas (JS puro)

   Integração com backend:
   Se existir no site uma instância global `db` com um método
   `db.insert(tabela, dados)` (tal como é usado no formulário de
   contacto do site, ex.: db.insert('sl_messages', {...})), este
   script tenta gravar o pedido em 'sl_bookings' automaticamente.
   Caso `db` não exista, o pedido fica apenas registado em memória
   (`window.__shutterliteBookings`) e no console, para que o
   formulário continue a funcionar de forma independente.
════════════════════════════════════════════════════════════ */
(function () {
  'use strict';

  const form = document.getElementById('bookingForm');
  if (!form) return; // secção não presente nesta página

  const submitBtn      = document.getElementById('bookingSubmitBtn');
  const successPanel   = document.getElementById('bookingSuccess');
  const formErrorBox   = document.getElementById('bookingFormError');
  const codeDisplay     = document.getElementById('bookingCodeDisplay');
  const copyBtn         = document.getElementById('bookingCopyBtn');
  const newBookingBtn   = document.getElementById('bookingNewBtn');
  const addressWrap     = document.getElementById('bkAddressWrap');
  const addressInput    = document.getElementById('bkAddress');
  const dateInput       = document.getElementById('bkDate');
  const locationRadios  = form.querySelectorAll('input[name="bkLocation"]');

  window.__shutterliteBookings = window.__shutterliteBookings || [];

  /* ── Data mínima = hoje ──────────────────────────────────── */
  (function setMinDate() {
    const today = new Date();
    const iso = today.toISOString().split('T')[0];
    dateInput.setAttribute('min', iso);
  })();

  /* ── Mostrar/ocultar endereço consoante o local ─────────── */
  function updateAddressVisibility() {
    const selected = form.querySelector('input[name="bkLocation"]:checked');
    const needsAddress = selected && selected.value !== 'Estúdio';
    addressWrap.classList.toggle('open', !!needsAddress);
    addressInput.required = !!needsAddress;
    if (!needsAddress) {
      clearFieldError('bkAddress');
    }
  }
  locationRadios.forEach(r => r.addEventListener('change', updateAddressVisibility));
  updateAddressVisibility();

  /* ── Helpers de validação visual ────────────────────────── */
  function fieldWrapperFor(id) {
    const el = document.getElementById(id);
    return el ? el.closest('.booking-field') : null;
  }
  function showFieldError(id, message) {
    const wrap = fieldWrapperFor(id) || document.querySelector('[data-field="' + id + '"]');
    if (!wrap) return;
    wrap.classList.add('invalid');
    if (message) {
      const errEl = wrap.querySelector('.booking-error');
      if (errEl) errEl.textContent = message;
    }
  }
  function clearFieldError(id) {
    const wrap = fieldWrapperFor(id) || document.querySelector('[data-field="' + id + '"]');
    if (wrap) wrap.classList.remove('invalid');
  }
  function clearAllErrors() {
    form.querySelectorAll('.booking-field.invalid').forEach(el => el.classList.remove('invalid'));
    formErrorBox.classList.remove('show');
  }

  /* ── Validadores individuais ─────────────────────────────── */
  const PHONE_RE = /^[+]?[\d\s().-]{7,17}$/;
  const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  function validators() {
    const v = [];

    v.push(() => {
      const val = document.getElementById('bkName').value.trim();
      if (val.length < 3) { showFieldError('bkName'); return false; }
      clearFieldError('bkName'); return true;
    });

    v.push(() => {
      const val = document.getElementById('bkPhone').value.trim();
      if (!PHONE_RE.test(val)) { showFieldError('bkPhone'); return false; }
      clearFieldError('bkPhone'); return true;
    });

    v.push(() => {
      const val = document.getElementById('bkEmail').value.trim();
      if (!EMAIL_RE.test(val)) { showFieldError('bkEmail'); return false; }
      clearFieldError('bkEmail'); return true;
    });

    v.push(() => {
      const val = document.getElementById('bkType').value;
      if (!val) { showFieldError('bkType'); return false; }
      clearFieldError('bkType'); return true;
    });

    v.push(() => {
      const val = document.getElementById('bkPackage').value;
      if (!val) { showFieldError('bkPackage'); return false; }
      clearFieldError('bkPackage'); return true;
    });

    v.push(() => {
      const val = dateInput.value;
      if (!val) { showFieldError('bkDate', 'Escolha uma data válida (a partir de hoje).'); return false; }
      const chosen = new Date(val + 'T00:00:00');
      const today = new Date(); today.setHours(0, 0, 0, 0);
      if (chosen < today) { showFieldError('bkDate', 'A data não pode ser no passado.'); return false; }
      clearFieldError('bkDate'); return true;
    });

    v.push(() => {
      const val = document.getElementById('bkTime').value;
      if (!val) { showFieldError('bkTime'); return false; }
      clearFieldError('bkTime'); return true;
    });

    v.push(() => {
      const val = document.getElementById('bkDuration').value;
      if (!val) { showFieldError('bkDuration'); return false; }
      clearFieldError('bkDuration'); return true;
    });

    v.push(() => {
      const val = parseInt(document.getElementById('bkPeople').value, 10);
      if (!val || val < 1) { showFieldError('bkPeople'); return false; }
      clearFieldError('bkPeople'); return true;
    });

    v.push(() => {
      const val = document.getElementById('bkStyle').value.trim();
      if (val.length < 3) { showFieldError('bkStyle'); return false; }
      clearFieldError('bkStyle'); return true;
    });

    v.push(() => {
      const selected = form.querySelector('input[name="bkLocation"]:checked');
      if (!selected) { showFieldError('bkLocation'); return false; }
      clearFieldError('bkLocation'); return true;
    });

    v.push(() => {
      if (!addressInput.required) { clearFieldError('bkAddress'); return true; }
      const val = addressInput.value.trim();
      if (val.length < 4) { showFieldError('bkAddress'); return false; }
      clearFieldError('bkAddress'); return true;
    });

    v.push(() => {
      const val = document.getElementById('bkPayment').value;
      if (!val) { showFieldError('bkPayment'); return false; }
      clearFieldError('bkPayment'); return true;
    });

    return v;
  }

  function runValidation() {
    const results = validators().map(fn => fn());
    return results.every(Boolean);
  }

  /* Validação em tempo real ao sair do campo */
  ['bkName', 'bkPhone', 'bkEmail', 'bkType', 'bkPackage', 'bkDate', 'bkTime',
   'bkDuration', 'bkPeople', 'bkStyle', 'bkAddress', 'bkPayment'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.addEventListener('blur', runValidation);
  });
  locationRadios.forEach(r => r.addEventListener('change', runValidation));

  /* ── Código único do pedido ──────────────────────────────── */
  function generateBookingCode() {
    const now = new Date();
    const ymd = now.toISOString().slice(0, 10).replace(/-/g, '');
    const rand = Math.random().toString(36).slice(2, 6).toUpperCase() +
                 Math.random().toString(36).slice(2, 4).toUpperCase();
    const code = `SL-${ymd}-${rand}`;
    // garante que não colide com um código já emitido nesta sessão
    const used = window.__shutterliteBookings.map(b => b.code);
    return used.includes(code) ? generateBookingCode() : code;
  }

  /* ── Envio ───────────────────────────────────────────────── */
  async function handleSubmit(e) {
    e.preventDefault();
    clearAllErrors();

    const valid = runValidation();
    if (!valid) {
      formErrorBox.classList.add('show');
      const firstInvalid = form.querySelector('.booking-field.invalid');
      if (firstInvalid) {
        firstInvalid.scrollIntoView({ behavior: 'smooth', block: 'center' });
        const focusable = firstInvalid.querySelector('input, select, textarea');
        if (focusable) focusable.focus();
      }
      return;
    }

    submitBtn.disabled = true;
    submitBtn.classList.add('loading');

    const code = generateBookingCode();
    const selectedLocation = form.querySelector('input[name="bkLocation"]:checked');

    const payload = {
      code,
      name: document.getElementById('bkName').value.trim(),
      phone: document.getElementById('bkPhone').value.trim(),
      email: document.getElementById('bkEmail').value.trim(),
      session_type: document.getElementById('bkType').value,
      package: document.getElementById('bkPackage').value,
      date: dateInput.value,
      time: document.getElementById('bkTime').value,
      duration: document.getElementById('bkDuration').value,
      people: parseInt(document.getElementById('bkPeople').value, 10),
      location: selectedLocation ? selectedLocation.value : '',
      address: addressInput.value.trim() || null,
      style: document.getElementById('bkStyle').value.trim(),
      notes: document.getElementById('bkNotes').value.trim() || null,
      payment_method: document.getElementById('bkPayment').value,
      status: 'pendente', // pedido — aguarda confirmação humana
      created_at: new Date().toISOString()
    };

    try {
      if (typeof db !== 'undefined' && db && typeof db.insert === 'function') {
        // Integração real com o backend do site (mesma lib usada no form de contacto)
        await db.insert('sl_bookings', payload);
      } else {
        // Fallback autónomo — mantém o formulário funcional sem backend ligado
        console.info('[Shutterlite Booking] Pedido registado localmente:', payload);
      }
      window.__shutterliteBookings.push(payload);
      showSuccess(code);
    } catch (err) {
      console.error('[Shutterlite Booking] Erro ao enviar pedido:', err);
      formErrorBox.textContent = 'Não foi possível enviar o pedido. Tente novamente ou contacte-nos diretamente.';
      formErrorBox.classList.add('show');
    } finally {
      submitBtn.disabled = false;
      submitBtn.classList.remove('loading');
    }
  }

  function showSuccess(code) {
    codeDisplay.textContent = code;
    form.hidden = true;
    successPanel.hidden = false;
    successPanel.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  copyBtn?.addEventListener('click', async () => {
    const text = codeDisplay.textContent.trim();
    try {
      await navigator.clipboard.writeText(text);
      const original = copyBtn.innerHTML;
      copyBtn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 12l5 5 11-11" stroke-linecap="round" stroke-linejoin="round"/></svg>';
      setTimeout(() => { copyBtn.innerHTML = original; }, 1600);
    } catch (err) {
      console.warn('Não foi possível copiar o código automaticamente.', err);
    }
  });

  newBookingBtn?.addEventListener('click', () => {
    form.reset();
    clearAllErrors();
    updateAddressVisibility();
    successPanel.hidden = true;
    form.hidden = false;
    form.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });

  form.addEventListener('submit', handleSubmit);
})();
