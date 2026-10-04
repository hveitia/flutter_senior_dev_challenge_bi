import { escapeHtml, renderPage } from "./page";
import { MAX_AMOUNT_CENTS, MIN_AMOUNT_CENTS, OPERATORS } from "./recharge";

const PARTNER = "Aliado Recargas";

function operatorOptions(): string {
  return Object.entries(OPERATORS)
    .map(
      ([id, label]) =>
        `<option value="${escapeHtml(id)}">${escapeHtml(label)}</option>`,
    )
    .join("");
}

const BODY = `
<main>
  <p class="eyebrow">${escapeHtml(PARTNER)}</p>
  <h1>Recargas</h1>
  <p class="lead">Siempre en contacto</p>

  <form id="top-up-form" novalidate>
    <label for="number">Celular</label>
    <input id="number" name="number" type="tel" inputmode="numeric" autocomplete="off"
      maxlength="10" placeholder="0991234567" aria-describedby="number-problem">
    <p class="problem" id="number-problem" role="alert" hidden></p>

    <label for="operator">Operadora</label>
    <select id="operator" name="operator" aria-describedby="operator-problem">
      <option value="">Selecciona tu operadora</option>
      ${operatorOptions()}
    </select>
    <p class="problem" id="operator-problem" role="alert" hidden></p>

    <label for="amount">Monto en USD</label>
    <input id="amount" name="amount" type="text" inputmode="decimal" autocomplete="off"
      placeholder="0.00" aria-describedby="amountCents-problem">
    <p class="problem" id="amountCents-problem" role="alert" hidden></p>

    <button id="submit" type="submit">Continuar</button>
    <p class="problem" id="form-problem" role="alert" hidden></p>
  </form>

  <section class="result" id="result" aria-live="polite" hidden>
    <h2>Recarga registrada</h2>
    <p class="amount" id="result-amount"></p>
    <p id="result-detail"></p>
    <p id="result-reference"></p>
    <button class="plain" id="close" type="button">Cerrar</button>
  </section>

  <p class="note">Demostración: no se realiza ningún cobro ni se acredita saldo.</p>
</main>
`;

const SCRIPT = String.raw`
(function () {
  'use strict';
  var MIN_CENTS = ${MIN_AMOUNT_CENTS};
  var MAX_CENTS = ${MAX_AMOUNT_CENTS};
  var INPUTS = { number: 'number', operator: 'operator', amountCents: 'amount' };
  var PROBLEMS = {
    'required': 'Completa este campo.',
    'not-a-mobile-number': 'Ingresa un celular de 10 dígitos que empiece con 09.',
    'unknown-operator': 'Elige una operadora de la lista.',
    'not-whole-cents': 'Ingresa un monto con hasta dos decimales.',
    'below-minimum': 'El monto mínimo es ' + partner.money(MIN_CENTS) + '.',
    'above-maximum': 'El monto máximo es ' + partner.money(MAX_CENTS) + '.'
  };
  var form = document.getElementById('top-up-form');
  var submit = document.getElementById('submit');
  var formProblem = document.getElementById('form-problem');
  var result = document.getElementById('result');

  // Dollars as text to whole cents, without going through a fraction.
  function cents(text) {
    var match = /^(\d{1,4})(?:[.,](\d{1,2}))?$/.exec(text.trim());
    if (!match) return text.trim() === '' ? '' : NaN;
    var fraction = (match[2] || '') + '00';
    return Number(match[1]) * 100 + Number(fraction.slice(0, 2));
  }

  function show(field, code) {
    var input = document.getElementById(INPUTS[field]);
    var problem = document.getElementById(field + '-problem');
    if (code) {
      input.setAttribute('aria-invalid', 'true');
      problem.textContent = PROBLEMS[code] || 'Revisa este campo.';
      problem.hidden = false;
    } else {
      input.removeAttribute('aria-invalid');
      problem.hidden = true;
    }
  }

  function fail(message) {
    formProblem.textContent = message;
    formProblem.hidden = false;
  }

  form.addEventListener('submit', function (event) {
    event.preventDefault();
    formProblem.hidden = true;
    submit.disabled = true;

    partner.send('/partners/recharge/top-up', {
      number: form.elements.number.value.trim(),
      operator: form.elements.operator.value,
      amountCents: cents(form.elements.amount.value)
    }).then(function (response) {
      var answer = response.answer;
      Object.keys(INPUTS).forEach(function (field) {
        show(field, answer.problems ? answer.problems[field] : null);
      });
      if (response.status === 422) {
        var first = Object.keys(INPUTS).filter(function (field) {
          return answer.problems && answer.problems[field];
        })[0];
        if (first) document.getElementById(INPUTS[first]).focus();
        return;
      }
      if (response.status !== 200) {
        fail('No pudimos registrar tu recarga. Intenta de nuevo.');
        return;
      }

      document.getElementById('result-amount').textContent =
        partner.money(answer.topUp.amountCents);
      document.getElementById('result-detail').textContent =
        answer.topUp.operatorLabel + ', ' + answer.topUp.maskedNumber;
      document.getElementById('result-reference').textContent =
        'Referencia: ' + answer.reference;
      form.hidden = true;
      result.hidden = false;
      partner.completed(answer.reference);
    }).catch(function () {
      fail('No pudimos registrar tu recarga. Revisa tu conexión e intenta de nuevo.');
    }).then(function () {
      submit.disabled = false;
    });
  });

  document.getElementById('close').addEventListener('click', function () {
    partner.close();
  });
})();
`;

export function rechargePage(nonce: string): string {
  return renderPage({
    title: `Recargas | ${PARTNER}`,
    body: BODY,
    script: SCRIPT,
    nonce,
  });
}
