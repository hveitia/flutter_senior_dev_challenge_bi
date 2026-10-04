import { escapeHtml, renderPage } from "./page";
import {
  FAMILY_DISCOUNT_PERCENT,
  MAX_TRAVELERS,
  REGIONS,
} from "./travel-insurance";

const PARTNER = "Aliado Seguros";

/** Where the partner publishes its conditions: another site, on purpose. */
const CONDITIONS_URL = "https://www.example.org/condiciones-seguro-de-viaje";

function regionOptions(): string {
  return Object.entries(REGIONS)
    .map(
      ([id, region]) =>
        `<option value="${escapeHtml(id)}">${escapeHtml(region.label)}</option>`,
    )
    .join("");
}

function travelerOptions(): string {
  return Array.from({ length: MAX_TRAVELERS }, (_, index) => {
    const travelers = index + 1;
    const label = travelers === 1 ? "1 persona" : `${travelers} personas`;
    return `<option value="${travelers}">${label}</option>`;
  }).join("");
}

const BODY = `
<main>
  <p class="eyebrow">${escapeHtml(PARTNER)}</p>
  <h1>Viaja con tranquilidad</h1>
  <p class="lead">Cotiza una protección para tu próximo viaje.</p>

  <form id="quote-form" novalidate>
    <label for="region">Destino</label>
    <select id="region" name="region" aria-describedby="region-problem">
      <option value="">Selecciona tu destino</option>
      ${regionOptions()}
    </select>
    <p class="problem" id="region-problem" role="alert" hidden></p>

    <label for="departure">Fecha de salida</label>
    <input id="departure" name="departure" type="date" aria-describedby="departure-problem">
    <p class="problem" id="departure-problem" role="alert" hidden></p>

    <label for="return">Fecha de regreso</label>
    <input id="return" name="return" type="date" aria-describedby="return-problem">
    <p class="problem" id="return-problem" role="alert" hidden></p>

    <label for="travelers">Personas que viajan</label>
    <select id="travelers" name="travelers" aria-describedby="travelers-problem">
      ${travelerOptions()}
    </select>
    <p class="problem" id="travelers-problem" role="alert" hidden></p>

    <button id="submit" type="submit">Cotizar mi seguro</button>
    <p class="problem" id="form-problem" role="alert" hidden></p>
  </form>

  <section class="result" id="result" aria-live="polite" hidden>
    <h2>Tu cotización</h2>
    <p class="amount" id="result-total"></p>
    <p id="result-detail"></p>
    <p id="result-discount" hidden></p>
    <button id="accept" type="button">Aceptar cotización</button>
    <p id="result-accepted" hidden></p>
  </section>

  <p class="note">La cotización y la cobertura son responsabilidad de ${escapeHtml(PARTNER)}.
    <a href="${escapeHtml(CONDITIONS_URL)}">Condiciones generales</a>.</p>
  <p class="note">Los clientes del segmento Familia reciben un ${FAMILY_DISCOUNT_PERCENT} % de descuento.</p>
  <p class="note">Demostración: no se emite ninguna póliza ni se realiza ningún cobro.</p>
</main>
`;

const SCRIPT = String.raw`
(function () {
  'use strict';
  var FIELDS = ['region', 'departure', 'return', 'travelers'];
  var PROBLEMS = {
    'required': 'Completa este campo.',
    'unknown-region': 'Elige un destino de la lista.',
    'not-a-date': 'Ingresa una fecha válida.',
    'in-the-past': 'La fecha de salida ya pasó.',
    'too-far-ahead': 'Cotizamos viajes que empiezan dentro de un año.',
    'before-departure': 'El regreso no puede ser antes de la salida.',
    'trip-too-long': 'Cotizamos viajes de hasta 90 días.',
    'out-of-range': 'Elige entre 1 y 6 personas.'
  };
  var form = document.getElementById('quote-form');
  var submit = document.getElementById('submit');
  var formProblem = document.getElementById('form-problem');
  var result = document.getElementById('result');
  var accept = document.getElementById('accept');
  var accepted = document.getElementById('result-accepted');
  var reference = null;

  function show(field, code) {
    var input = document.getElementById(field);
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
    result.hidden = true;
    submit.disabled = true;

    partner.send('/partners/travel-insurance/quote', {
      region: form.elements.region.value,
      departure: form.elements.departure.value,
      'return': form.elements['return'].value,
      travelers: Number(form.elements.travelers.value),
      segment: partner.context.segment
    }).then(function (response) {
      var answer = response.answer;
      FIELDS.forEach(function (field) {
        show(field, answer.problems ? answer.problems[field] : null);
      });
      if (response.status === 422) {
        var first = FIELDS.filter(function (field) {
          return answer.problems && answer.problems[field];
        })[0];
        if (first) document.getElementById(first).focus();
        return;
      }
      if (response.status !== 200) {
        fail('No pudimos cotizar tu seguro. Intenta de nuevo.');
        return;
      }

      reference = answer.reference;
      document.getElementById('result-total').textContent =
        partner.money(answer.quote.totalCents);
      document.getElementById('result-detail').textContent =
        answer.quote.regionLabel + ', ' + answer.quote.days +
        (answer.quote.days === 1 ? ' día, ' : ' días, ') + answer.quote.travelers +
        (answer.quote.travelers === 1 ? ' persona.' : ' personas.');
      var discount = document.getElementById('result-discount');
      discount.hidden = answer.quote.discountPercent === 0;
      discount.textContent =
        'Incluye un descuento del ' + answer.quote.discountPercent + ' %.';
      accept.hidden = false;
      accepted.hidden = true;
      result.hidden = false;
      result.scrollIntoView();
    }).catch(function () {
      fail('No pudimos cotizar tu seguro. Revisa tu conexión e intenta de nuevo.');
    }).then(function () {
      submit.disabled = false;
    });
  });

  accept.addEventListener('click', function () {
    accept.hidden = true;
    accepted.textContent = 'Cotización aceptada. Referencia: ' + reference;
    accepted.hidden = false;
    partner.completed(reference);
  });
})();
`;

export function travelInsurancePage(nonce: string): string {
  return renderPage({
    title: `Seguro de viaje | ${PARTNER}`,
    body: BODY,
    script: SCRIPT,
    nonce,
  });
}
