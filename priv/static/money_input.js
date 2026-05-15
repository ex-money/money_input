// MoneyInput Phoenix LiveView hooks.
//
// Exports three hooks:
//
//   NumberInput     — locale-aware live formatting for plain numbers
//   MoneyInput      — same, with currency-aware precision
//   CurrencyPicker  — searchable currency picker (recents, sheet,
//                     keyboard nav, flag glyphs)
//
// AutoNumeric (https://autonumeric.org/) is a *peer* dependency.
// Install it in the host app:
//
//   npm install autonumeric
//
// And expose it on window before importing these hooks, or pass it
// in via `MoneyInputHooks.configure({ AutoNumeric })` before
// constructing your LiveSocket. When AutoNumeric isn't available
// the hooks degrade to the Path A baseline: the input still works,
// the server-side parser still accepts whatever the user typed,
// but live formatting and cursor preservation are off.

let AutoNumericCtor =
  (typeof window !== "undefined" && window.AutoNumeric) || null;

/** Inject a specific AutoNumeric constructor (for bundlers that
 *  don't put it on window). Call this before `new LiveSocket`. */
export function configure({ AutoNumeric }) {
  AutoNumericCtor = AutoNumeric || AutoNumericCtor;
}

// ── Number / money hooks ──────────────────────────────────────

function readData(el) {
  const d = el.dataset;
  const num = (v) => (v == null || v === "" ? null : Number(v));
  return {
    locale: d.locale || "en",
    decimal: d.decimal || ".",
    group: d.group || ",",
    minus: d.minus || "-",
    digitSystem: d.digitSystem || "latn",
    integer: d.integer === "true",
    decimals: num(d.decimals),
    isoDigits: num(d.isoDigits),
    min: d.min || null,
    max: d.max || null,
    currency: d.currency || null,
    symbolPosition: d.symbolPosition || "prefix",
  };
}

function buildAutoNumericOptions(data, kind) {
  const decimals =
    kind === "money"
      ? data.isoDigits ?? 2
      : data.decimals ?? (data.integer ? 0 : 6);

  const opts = {
    decimalCharacter: data.decimal,
    digitGroupSeparator: data.group,
    decimalCharacterAlternative: data.decimal === "." ? "," : ".",
    negativeSignCharacter: data.minus,
    decimalPlaces: decimals,
    decimalPlacesShownOnFocus: decimals,
    decimalPlacesShownOnBlur: decimals,
    allowDecimalPadding: false,
    currencySymbol: "",
    selectOnFocus: false,
    modifyValueOnWheel: false,
    minimumValue: data.min ?? "-10000000000000",
    maximumValue: data.max ?? "10000000000000",
    onInvalidPaste: "clamp",
    digitalGroupSpacing: data.locale && data.locale.startsWith("en-IN") ? "2s" : "3",
  };
  return opts;
}

function attachCanonicalSubmit(input, getCanonical) {
  // On submit, replace the locale-formatted display value with
  // the canonical period-decimal form (e.g. "1.234,56" → "1234.56")
  // so the server-side cast doesn't need to know the locale to
  // parse it. The change is in-place on the same input, which
  // means the field name stays nested (`price[amount]`) and the
  // server sees a clean `%{"amount" => "1234.56", "currency" =>
  // "EUR"}` map ready for `Money.Ecto.Composite.Type` or
  // `Money.Input.Changeset.cast_money/3`.
  const form = input.form;
  if (!form) return () => {};
  const handler = () => {
    const canonical = getCanonical();
    if (canonical !== null && canonical !== undefined) {
      input.value = canonical;
    }
  };
  form.addEventListener("submit", handler);
  return () => form.removeEventListener("submit", handler);
}

function cssEscape(value) {
  if (window.CSS && CSS.escape) return CSS.escape(value);
  return value.replace(/[^a-zA-Z0-9_-]/g, "\\$&");
}

function mountInput(hook, kind) {
  hook.input = hook.el.querySelector("input.money-input-field");
  if (!hook.input) return;

  const data = readData(hook.el);
  hook.data = data;

  if (!AutoNumericCtor) {
    // Path A fallback. The form still submits; the server-side
    // parser still accepts the locale-typed string. We only lose
    // the live formatting + cursor preservation.
    hook.input.addEventListener("paste", (event) =>
      paste_sanitize(event, data),
    );
    return;
  }

  hook.an = new AutoNumericCtor(
    hook.input,
    buildAutoNumericOptions(data, kind),
  );

  hook.detachSubmit = attachCanonicalSubmit(hook.input, () =>
    hook.an.getNumber(),
  );

  if (kind === "money") {
    // Listen for currency changes from a sibling picker so the
    // input's precision can adapt mid-input.
    hook.onCurrencyChange = (event) => {
      const newCurrency = event.detail && event.detail.currency;
      const newDigits = event.detail && event.detail.isoDigits;
      if (newCurrency) hook.el.dataset.currency = newCurrency;
      if (typeof newDigits === "number") {
        hook.an.update({
          decimalPlaces: newDigits,
          decimalPlacesShownOnFocus: newDigits,
          decimalPlacesShownOnBlur: newDigits,
        });
      }
    };
    hook.el.addEventListener("money-input:currency-change", hook.onCurrencyChange);
  }
}

function destroyInput(hook) {
  if (hook.detachSubmit) hook.detachSubmit();
  if (hook.an) hook.an.remove();
  if (hook.onCurrencyChange)
    hook.el.removeEventListener(
      "money-input:currency-change",
      hook.onCurrencyChange,
    );
}

function paste_sanitize(event, data) {
  // Pre-AutoNumeric paste handler used only in the fallback path.
  // Strip obvious decorations so the server-side parser doesn't
  // have to.
  const text = (event.clipboardData || window.clipboardData).getData("text");
  if (!text) return;
  event.preventDefault();
  const cleaned = text
    .replace(/[   ]/g, " ")
    .replace(/[−–—]/g, "-")
    .replace(/^\((.*)\)$/, "-$1")
    .trim();
  const input = event.target;
  const start = input.selectionStart || 0;
  const end = input.selectionEnd || 0;
  input.value = input.value.slice(0, start) + cleaned + input.value.slice(end);
  const cursor = start + cleaned.length;
  input.setSelectionRange(cursor, cursor);
}

export const NumberInput = {
  mounted() {
    mountInput(this, "number");
  },
  destroyed() {
    destroyInput(this);
  },
};

export const MoneyInput = {
  mounted() {
    mountInput(this, "money");
  },
  destroyed() {
    destroyInput(this);
  },
};

// ── Currency picker ───────────────────────────────────────────

const RECENTS_KEY = "money_input:recents";
const SHEET_BREAKPOINT_PX = 640;

function loadRecents() {
  try {
    return JSON.parse(localStorage.getItem(RECENTS_KEY) || "[]");
  } catch (_) {
    return [];
  }
}

function saveRecents(list) {
  try {
    localStorage.setItem(RECENTS_KEY, JSON.stringify(list));
  } catch (_) {
    /* private mode etc — silently ignore */
  }
}

function pushRecent(code, limit) {
  const list = loadRecents().filter((c) => c !== code);
  list.unshift(code);
  saveRecents(list.slice(0, limit));
  return list;
}

export const CurrencyPicker = {
  mounted() {
    this.trigger = this.el.querySelector("[data-currency-picker-trigger]");
    this.overlay = this.el.querySelector("[data-currency-picker-overlay]");
    this.search = this.el.querySelector("[data-currency-picker-search]");
    this.list = this.el.querySelector("[data-currency-picker-list]");
    this.closeBtn = this.el.querySelector("[data-currency-picker-close]");
    this.valueInput = this.el.querySelector("[data-currency-picker-value]");
    this.empty = this.el.querySelector("[data-currency-picker-empty]");

    this.recentsLimit = parseInt(this.el.dataset.recentsLimit || "5", 10);
    this.variant = this.el.dataset.variant || "auto";

    this.onTriggerClick = (e) => {
      e.preventDefault();
      this.open();
    };
    this.onCloseClick = () => this.close();
    this.onSearchInput = () => this.filter();
    this.onListClick = (e) => {
      const row = e.target.closest("[data-currency-picker-row]");
      if (!row) return;
      // Prevent the click from bubbling to the document-level
      // outside-click handler attached in `open()`. If that
      // handler still runs, it calls `close()` with the default
      // `refocus: true`, which yanks focus back to the trigger
      // immediately after `selectCode` placed it on the paired
      // input. Browsers disagree on whether a listener removed
      // mid-dispatch fires for the same event, so be defensive.
      e.stopPropagation();
      e.preventDefault();
      this.selectCode(row.dataset.code);
    };
    this.onKeydown = (e) => this.handleKeydown(e);
    this.onDocClick = (e) => {
      if (!this.el.contains(e.target)) this.close();
    };

    this.trigger.addEventListener("click", this.onTriggerClick);
    this.closeBtn.addEventListener("click", this.onCloseClick);
    this.search.addEventListener("input", this.onSearchInput);
    this.list.addEventListener("click", this.onListClick);
    this.el.addEventListener("keydown", this.onKeydown);

    this.applyRecents();
    this.applySheetVariant();
  },

  destroyed() {
    this.trigger.removeEventListener("click", this.onTriggerClick);
    this.closeBtn.removeEventListener("click", this.onCloseClick);
    this.search.removeEventListener("input", this.onSearchInput);
    this.list.removeEventListener("click", this.onListClick);
    this.el.removeEventListener("keydown", this.onKeydown);
    document.removeEventListener("click", this.onDocClick);
  },

  applyRecents() {
    const recents = loadRecents().slice(0, this.recentsLimit);
    if (recents.length === 0) return;

    // Build (or refresh) a "Recents" section at the top of the
    // list. Implemented in JS so the server never sees user
    // localStorage state.
    let section = this.list.querySelector(".currency-picker-section-recents");
    if (!section) {
      section = document.createElement("li");
      section.className =
        "currency-picker-section currency-picker-section-recents";
      section.setAttribute("role", "presentation");
      section.textContent = "Recents";
      this.list.insertBefore(section, this.list.firstChild);
    }

    // Remove previous recent rows and reinsert clones in order.
    this.list
      .querySelectorAll("[data-currency-picker-row].is-recent")
      .forEach((node) => node.remove());

    let anchor = section.nextSibling;
    recents.forEach((code) => {
      const source = this.list.querySelector(
        `[data-currency-picker-row][data-code="${cssEscape(code)}"]`,
      );
      if (!source) return;
      const clone = source.cloneNode(true);
      clone.classList.add("is-recent");
      this.list.insertBefore(clone, anchor);
    });
  },

  applySheetVariant() {
    const useSheet =
      this.variant === "sheet" ||
      (this.variant === "auto" &&
        window.matchMedia(`(max-width: ${SHEET_BREAKPOINT_PX}px)`).matches);
    this.el.classList.toggle("is-sheet", useSheet);
  },

  open() {
    this.overlay.hidden = false;
    this.trigger.setAttribute("aria-expanded", "true");
    this.applySheetVariant();

    // The picker is rendered inside the money-input-wrapper,
    // which has `overflow: hidden` for its rounded corners. Float
    // the overlay with `position: fixed` so it escapes the clip
    // region. The sheet variant already uses position:fixed via
    // CSS and covers the whole viewport.
    if (!this.el.classList.contains("is-sheet")) {
      this.positionOverlay();
      this.repositionHandler = () => this.positionOverlay();
      window.addEventListener("resize", this.repositionHandler);
      window.addEventListener("scroll", this.repositionHandler, true);
    }

    setTimeout(() => {
      this.search.value = "";
      this.filter();
      this.search.focus();
      document.addEventListener("click", this.onDocClick);
    }, 0);
  },

  close({ refocus = true } = {}) {
    this.overlay.hidden = true;
    this.trigger.setAttribute("aria-expanded", "false");
    document.removeEventListener("click", this.onDocClick);
    if (this.repositionHandler) {
      window.removeEventListener("resize", this.repositionHandler);
      window.removeEventListener("scroll", this.repositionHandler, true);
      this.repositionHandler = null;
    }
    this.overlay.style.position = "";
    this.overlay.style.top = "";
    this.overlay.style.left = "";
    this.overlay.style.width = "";
    if (refocus) this.trigger.focus();
  },

  positionOverlay() {
    const rect = this.trigger.getBoundingClientRect();
    const overlayWidth = Math.max(rect.width, 320);
    const maxLeft = Math.max(8, window.innerWidth - overlayWidth - 8);
    this.overlay.style.position = "fixed";
    this.overlay.style.top = `${rect.bottom + 4}px`;
    this.overlay.style.left = `${Math.min(rect.left, maxLeft)}px`;
    this.overlay.style.width = `${overlayWidth}px`;
  },

  filter() {
    const term = this.search.value.trim().toLowerCase();
    const rows = this.list.querySelectorAll("[data-currency-picker-row]");
    let visible = 0;
    rows.forEach((row) => {
      const hay = `${row.dataset.code} ${row.dataset.name} ${row.dataset.country} ${row.dataset.symbol}`.toLowerCase();
      const match = !term || hay.includes(term);
      row.hidden = !match;
      if (match) visible++;
    });
    if (this.empty) this.empty.hidden = visible > 0;
  },

  selectCode(code) {
    if (!code) return;
    this.el.dataset.current = code;
    const codeNode = this.trigger.querySelector(".currency-picker-code");
    if (codeNode) codeNode.textContent = code;
    const flagNode = this.trigger.querySelector(".currency-picker-flag");
    const row = this.list.querySelector(
      `[data-currency-picker-row][data-code="${cssEscape(code)}"]`,
    );
    if (row && flagNode) {
      const newFlag = row.querySelector(".currency-picker-flag");
      if (newFlag) flagNode.textContent = newFlag.textContent;
    }
    if (this.valueInput) {
      this.valueInput.value = code;
      this.valueInput.dispatchEvent(new Event("change", { bubbles: true }));
    }

    // Walk up to the surrounding money-input wrapper (if any) and
    // notify it so the precision adapts immediately. The server
    // is also notified via the hidden input's change event so
    // `on_currency_change` events fire as expected.
    const wrapper = this.el.closest("[data-money-input]");
    if (wrapper) {
      const isoDigits = row && parseInt(row.dataset.isoDigits || "2", 10);
      wrapper.dispatchEvent(
        new CustomEvent("money-input:currency-change", {
          detail: { currency: code, isoDigits },
          bubbles: true,
        }),
      );
    }

    pushRecent(code, this.recentsLimit);

    // Hand focus back to the paired money input rather than the
    // trigger — picking a currency is almost always followed by
    // typing an amount, so dropping the user back into the
    // amount field is the right next action. Falls back to the
    // trigger when no paired input is found (the picker is being
    // used standalone, e.g. as a "show prices in" widget).
    const pairedInput = wrapper && wrapper.querySelector("input.money-input-field");
    if (pairedInput) {
      this.close({ refocus: false });
      pairedInput.focus();
      // Place the caret at the end so the next keystroke appends
      // rather than overwriting a partial number.
      const length = pairedInput.value.length;
      try {
        pairedInput.setSelectionRange(length, length);
      } catch (_) {
        // Not all input types support setSelectionRange; ignore.
      }
    } else {
      this.close();
    }
  },

  handleKeydown(e) {
    if (e.key === "Escape") {
      e.preventDefault();
      this.close();
      return;
    }
    if (this.overlay.hidden) return;
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      const rows = Array.from(
        this.list.querySelectorAll("[data-currency-picker-row]"),
      ).filter((row) => !row.hidden);
      if (rows.length === 0) return;
      const focused = document.activeElement;
      let idx = rows.indexOf(focused);
      idx = (idx + (e.key === "ArrowDown" ? 1 : -1) + rows.length) % rows.length;
      rows[idx].focus();
    } else if (e.key === "Enter") {
      const focused = document.activeElement;
      if (focused && focused.dataset && focused.dataset.code) {
        e.preventDefault();
        this.selectCode(focused.dataset.code);
      }
    }
  },
};

export default { NumberInput, MoneyInput, CurrencyPicker, configure };
