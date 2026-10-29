// Shows the pet sheet a tutor shared. The token is in the address after the
// "#", so it never reaches the GitHub Pages server or its logs; it goes only
// to the pet-share function, in the body of a POST.
'use strict';

(function () {
  const config = window.BOWIE_CONFIG || {};
  const sheet = document.getElementById('sheet');
  const foot = document.getElementById('foot');

  // Lucide icons (ISC license), inline so the page needs nothing else.
  const ICONS = {
    alert: '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
    shield: '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="M12 8v4"/><path d="M12 16h.01"/>',
    utensils: '<path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2"/><path d="M7 2v20"/><path d="M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7"/>',
    pill: '<path d="m10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7Z"/><path d="m8.5 8.5 7 7"/>',
    syringe: '<path d="m18 2 4 4"/><path d="m17 7 3-3"/><path d="M19 9 8.7 19.3c-1 1-2.5 1-3.4 0l-.6-.6c-1-1-1-2.5 0-3.4L15 5"/><path d="m9 11 4 4"/><path d="m5 19-3 3"/><path d="m14 4 6 6"/>',
    phone: '<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/>',
    message: '<path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/>',
    file: '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/>',
    calendar: '<path d="M8 2v4"/><path d="M16 2v4"/><rect width="18" height="18" x="3" y="4" rx="2"/><path d="M3 10h18"/>',
    proof: '<path d="M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z"/><path d="m9 12 2 2 4-4"/>',
    ok: '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
    clock: '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
    late: '<circle cx="12" cy="12" r="10"/><line x1="12" x2="12" y1="8" y2="12"/><line x1="12" x2="12.01" y1="16" y2="16"/>',
    paw: '<circle cx="11" cy="4" r="2"/><circle cx="18" cy="8" r="2"/><circle cx="20" cy="16" r="2"/><path d="M9 10a5 5 0 0 1 5 5v3.5a3.5 3.5 0 0 1-6.84 1.045Q6.52 17.48 4.46 16.84A3.5 3.5 0 0 1 5.5 10Z"/>',
    user: '<circle cx="12" cy="8" r="5"/><path d="M20 21a8 8 0 0 0-16 0"/>',
  };

  function icon(name) {
    const span = document.createElement('span');
    span.setAttribute('aria-hidden', 'true');
    span.style.display = 'inline-flex';
    // Static markup from ICONS only; data from the server never goes here.
    span.innerHTML = '<svg class="icon" viewBox="0 0 24 24">' + ICONS[name] + '</svg>';
    return span.firstChild;
  }

  // Builds an element. Text always goes in as text, never as HTML.
  function h(tag, attrs, ...children) {
    const el = document.createElement(tag);
    for (const [key, value] of Object.entries(attrs || {})) {
      if (value == null || value === false) continue;
      if (key === 'class') el.className = value;
      else el.setAttribute(key, value === true ? '' : value);
    }
    for (const child of children.flat()) {
      if (child == null || child === false) continue;
      el.append(child instanceof Node ? child : document.createTextNode(String(child)));
    }
    return el;
  }

  function day(iso) {
    if (!iso) return '';
    const [y, m, d] = iso.slice(0, 10).split('-');
    return d + '/' + m + '/' + y;
  }

  function age(birth, today, estimated) {
    if (!birth) return null;
    const [by, bm, bd] = birth.split('-').map(Number);
    const [ty, tm, td] = today.split('-').map(Number);
    let months = (ty - by) * 12 + (tm - bm) - (td < bd ? 1 : 0);
    if (months < 0) return null;
    const years = Math.floor(months / 12);
    months = months % 12;
    let text;
    if (years === 0) text = months <= 1 ? (months === 1 ? '1 mês' : 'menos de 1 mês') : months + ' meses';
    else text = years === 1 ? '1 ano' : years + ' anos';
    if (years > 0 && years < 3 && months > 0) text += months === 1 ? ' e 1 mês' : ' e ' + months + ' meses';
    return (estimated ? 'cerca de ' : '') + text;
  }

  function phoneText(digits) {
    if (!digits || digits.length < 10) return digits || '';
    const rest = digits.slice(2);
    const split = rest.length - 4;
    return '(' + digits.slice(0, 2) + ') ' + rest.slice(0, split) + '-' + rest.slice(split);
  }

  function due(days, next) {
    if (days < 0) return days === -1 ? 'Venceu ontem' : 'Venceu há ' + -days + ' dias';
    if (days === 0) return 'Vence hoje';
    if (days === 1) return 'Vence amanhã';
    if (days <= 30) return 'Vence em ' + days + ' dias';
    return 'Em dia até ' + day(next);
  }

  // "do Bowie", "da Luna", "de Bowie" when the sex is unknown.
  function of(pet) {
    if (pet.sex === 'male') return 'do ' + pet.name;
    if (pet.sex === 'female') return 'da ' + pet.name;
    return 'de ' + pet.name;
  }

  const NOTE = {
    special_care: ['alert', 'Cuidado especial', 'warn'],
    allergy: ['shield', 'Alergia', 'warn'],
    diet: ['utensils', 'Alimentação', 'muted'],
  };
  const EVENT = { symptom: 'Sintoma', vet_visit: 'Consulta', exam: 'Exame', weight: 'Peso', other: 'Outro' };

  function section(iconName, title, ...content) {
    return [h('h2', {}, icon(iconName), title), ...content];
  }

  function photos(urls, label) {
    if (!urls || urls.length === 0) return null;
    return h('div', { class: 'thumbs' }, urls.map((url, i) =>
      h('a', { href: url, target: '_blank', rel: 'noopener' },
        h('img', { src: url, alt: label + ' ' + (i + 1) + ' de ' + urls.length, loading: 'lazy' }))));
  }

  function render(data) {
    const pet = data.pet;
    document.title = 'Ficha ' + of(pet) + ' · Bowie';
    const facts = [
      pet.species === 'dog' ? 'Cão' : pet.species === 'cat' ? 'Gato' : null,
      pet.sex === 'male' ? 'Macho' : pet.sex === 'female' ? 'Fêmea' : null,
      pet.breed,
      age(pet.birth_date, data.today, pet.birth_date_estimated),
      pet.weight_kg ? String(pet.weight_kg).replace('.', ',') + ' kg' : null,
      pet.size ? 'Porte ' + pet.size.toLowerCase() : null,
    ].filter(Boolean).join(' · ');

    const parts = [];
    parts.push(h('div', { class: 'card pet' },
      pet.photo_url
        ? h('img', { src: pet.photo_url, alt: 'Foto ' + of(pet) })
        : h('div', { class: 'nophoto' }, icon('paw')),
      h('div', {}, h('h1', {}, pet.name), h('p', {}, facts),
        pet.birth_date ? h('p', { class: 'caption' }, 'Nascimento: ' + day(pet.birth_date) + (pet.birth_date_estimated ? ' (aproximado)' : '')) : null)));

    if (data.notes.length > 0) {
      parts.push(...section('alert', 'Importante sobre ' + pet.name,
        h('div', { class: 'card rows' }, data.notes.map((note) => {
          const [name, label, tone] = NOTE[note.kind] || NOTE.special_care;
          const mark = icon(name);
          mark.classList.add(tone === 'warn' ? 'warn' : 'muted');
          return h('div', { class: 'item' }, mark,
            h('div', {}, h('h3', {}, note.title),
              h('p', { class: 'callout muted' }, [label, note.details].filter(Boolean).join(' · '))));
        }))));
    }

    // The contact comes early: it is what a hotel needs in a hurry.
    const hasContact = (t) => t && (t.name || t.phone || t.email);
    const contactCard = (t, fallback) => {
      const whatsapp = t.phone && t.phone.length === 11 ? 'https://wa.me/55' + t.phone : null;
      return h('div', { class: 'card' },
        h('h3', {}, t.name || fallback),
        t.phone ? h('p', { class: 'callout' }, phoneText(t.phone)) : null,
        t.email ? h('p', { class: 'callout' }, h('a', { href: 'mailto:' + t.email }, t.email)) : null,
        t.phone ? h('div', { class: 'actions' },
          h('a', { class: 'button', href: 'tel:+55' + t.phone }, icon('phone'), 'Ligar'),
          whatsapp ? h('a', { class: 'button secondary', href: whatsapp, target: '_blank', rel: 'noopener' }, icon('message'), 'WhatsApp') : null) : null);
    };
    const tutor = data.tutor;
    if (hasContact(tutor)) {
      parts.push(...section('user', 'Tutor principal', contactCard(tutor, 'Tutor ' + of(pet))));
    }
    const others = (data.other_tutors || []).filter(hasContact);
    if (others.length > 0) {
      parts.push(...section('user', others.length === 1 ? 'Outro tutor' : 'Outros tutores',
        h('p', { class: 'muted' }, 'Se não conseguir falar com o tutor principal.'),
        h('div', { class: 'stack' }, others.map((t) => contactCard(t, 'Tutor ' + of(pet))))));
    }

    parts.push(...section('pill', 'Remédios em uso',
      data.medications.length === 0
        ? h('p', { class: 'muted' }, 'Nenhum remédio em uso registrado.')
        : h('div', { class: 'card rows' }, data.medications.map((med) =>
          h('div', {},
            h('h3', {}, med.name),
            h('p', { class: 'callout' }, med.dose + (med.schedule ? ' · ' + med.schedule : '')),
            h('p', { class: 'caption' }, med.end_on ? 'Até ' + day(med.end_on) : 'Uso contínuo'),
            med.notes ? h('p', { class: 'caption' }, med.notes) : null)))));

    parts.push(...section('syringe', 'Vacinas, vermífugos e antipulgas',
      data.vaccines.length === 0
        ? h('p', { class: 'muted' }, 'Nenhuma vacina registrada.')
        : h('div', { class: 'stack' }, data.vaccines.map((group) => {
          const latest = group.doses[0];
          const tone = { overdue: ['late', 'late'], due_soon: ['soon', 'clock'], up_to_date: ['ok', 'ok'] }[group.status];
          const withProof = group.doses.some((d) => d.proofs.length > 0);
          const older = group.doses.slice(1);
          return h('div', { class: 'card' },
            h('h3', {}, group.name + ({ dewormer: ' (vermífugo)', flea_tick: ' (pulgas e carrapatos)' }[group.kind] || '')),
            h('div', { class: 'badges' },
              h('span', { class: 'badge ' + tone[0] }, icon(tone[1]), due(group.days_left, latest.next_due_on)),
              h('span', { class: 'badge ' + (withProof ? 'ok' : 'plain') }, icon('proof'), withProof ? 'Com comprovante' : 'Sem comprovante')),
            h('p', { class: 'callout' }, 'Última dose: ' + day(latest.applied_on) + (group.kind === 'flea_tick' ? ' · Trocar em: ' : ' · Próxima: ') + day(latest.next_due_on)),
            [latest.product, latest.lot ? 'Lote ' + latest.lot : null, latest.veterinarian].filter(Boolean).length > 0
              ? h('p', { class: 'caption' }, [latest.product, latest.lot ? 'Lote ' + latest.lot : null, latest.veterinarian].filter(Boolean).join(' · '))
              : null,
            photos(latest.proofs, 'Comprovante'),
            older.length > 0
              ? h('details', {}, h('summary', {}, older.length === 1 ? '1 dose anterior' : older.length + ' doses anteriores'),
                h('div', { class: 'rows' }, older.map((dose) => h('div', {},
                  h('p', { class: 'callout' }, day(dose.applied_on) + (dose.product ? ' · ' + dose.product : '')),
                  photos(dose.proofs, 'Comprovante')))))
              : null);
        }))));

    if (data.events) {
      parts.push(...section('calendar', 'Diário',
        data.events.length === 0
          ? h('p', { class: 'muted' }, 'Nenhum registro no diário.')
          : h('div', { class: 'card rows' }, data.events.map((event) =>
            h('div', {},
              h('p', { class: 'caption' }, [day(event.occurs_on) + (event.time ? ' às ' + event.time : ''), EVENT[event.kind] || 'Outro', event.contact].filter(Boolean).join(' · ')),
              h('h3', {}, event.title),
              event.notes ? h('p', { class: 'callout' }, event.notes) : null,
              photos(event.photos, 'Foto'),
              event.files.length > 0
                ? h('div', { class: 'files' }, event.files.map((file) =>
                  h('a', { class: 'file', href: file.url, target: '_blank', rel: 'noopener' }, icon('file'), file.name)))
                : null)))));
    }

    sheet.replaceChildren(...parts);
    foot.replaceChildren(
      h('p', {}, 'Ficha compartilhada pelo app Bowie. Os dados são os registrados pelos tutores e estão sempre atualizados. O Bowie não faz diagnóstico.'),
      h('p', {}, 'Este link vale até ' + day(data.expires_at) + '. As fotos e os arquivos abrem por 1 hora; depois, recarregue a página.'));
    const print = document.getElementById('print');
    print.hidden = false;
    print.addEventListener('click', () => window.print());
  }

  function fail(message) {
    sheet.replaceChildren(h('div', { class: 'center' },
      h('p', { class: 'muted' }, message)));
  }

  async function load() {
    const token = (location.hash.slice(1) || new URLSearchParams(location.search).get('t') || '').trim();
    if (!/^[A-Za-z0-9_-]{32,64}$/.test(token)) {
      fail('Este link está incompleto. Confira se copiou o endereço inteiro.');
      return;
    }
    if (!config.supabaseUrl) {
      fail('Esta página ainda não foi configurada.');
      return;
    }
    const headers = { 'Content-Type': 'application/json' };
    if (config.anonKey) {
      headers.apikey = config.anonKey;
      headers.Authorization = 'Bearer ' + config.anonKey;
    }
    let response;
    try {
      response = await fetch(config.supabaseUrl.replace(/\/$/, '') + '/functions/v1/pet-share', {
        method: 'POST',
        headers,
        body: JSON.stringify({ token }),
        cache: 'no-store',
        referrerPolicy: 'no-referrer',
      });
    } catch (_) {
      fail('Não foi possível abrir a ficha. Confira a internet e tente de novo.');
      return;
    }
    let data = null;
    try { data = await response.json(); } catch (_) { /* shown below */ }
    if (!response.ok || !data || !data.pet) {
      fail((data && data.message) || 'Não foi possível abrir a ficha agora. Tente de novo em alguns minutos.');
      return;
    }
    render(data);
  }

  window.addEventListener('hashchange', load);
  load();
})();
