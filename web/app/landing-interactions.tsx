"use client";

import { useEffect } from "react";

const samples = [
  {
    text: "chicken burrito bowl with guac",
    label: "LUNCH LOGGED",
    value: "760 cal · 48g protein"
  },
  {
    text: "bench press, 5 sets of 5 at 185",
    label: "PUSH DAY LOGGED",
    value: "5 × 5 · 185 lb"
  },
  {
    text: "ran 3 miles before work",
    label: "CARDIO LOGGED",
    value: "28 min · 3.0 mi"
  },
  {
    text: "greek yogurt and a banana",
    label: "SNACK LOGGED",
    value: "240 cal · 18g protein"
  }
];

const privacyNotes = {
  Private: "// Only you can see your profile and proof.",
  Friends: "// Approved friends can see this.",
  Public: "// Anyone can see proof you choose to share."
};

export function LandingInteractions() {
  useEffect(() => {
    const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const nav = document.getElementById("nav");

    const onScroll = () => {
      nav?.classList.toggle("scrolled", window.scrollY > 8);
    };

    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });

    const revealEls = Array.from(document.querySelectorAll<HTMLElement>(".reveal"));
    let observer: IntersectionObserver | undefined;

    if (!prefersReduced && "IntersectionObserver" in window) {
      observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              entry.target.classList.add("in");
              observer?.unobserve(entry.target);
            }
          });
        },
        { threshold: 0.14 }
      );

      revealEls.forEach((el) => observer?.observe(el));
      window.setTimeout(() => revealEls.forEach((el) => el.classList.add("in")), 1200);
    } else {
      revealEls.forEach((el) => el.classList.add("in"));
    }

    const buttons = Array.from(document.querySelectorAll<HTMLButtonElement>("[data-priv]"));
    const note = document.getElementById("privNote");
    const onPrivacyClick = (event: Event) => {
      const button = event.currentTarget as HTMLButtonElement;
      buttons.forEach((item) => item.classList.remove("active"));
      button.classList.add("active");
      const key = button.textContent?.trim() as keyof typeof privacyNotes;
      if (note && key in privacyNotes) note.textContent = privacyNotes[key];
    };
    buttons.forEach((button) => button.addEventListener("click", onPrivacyClick));

    const textEl = document.getElementById("floatText");
    const result = document.getElementById("floatResult");
    const label = document.getElementById("floatResultLabel");
    const value = document.getElementById("floatResultValue");
    let sampleIndex = 0;
    let charIndex = 0;
    let timeout: number | undefined;

    const typeLoop = () => {
      if (!textEl || !result || !label || !value) return;
      const current = samples[sampleIndex];
      result.classList.remove("show");
      textEl.textContent = current.text.slice(0, charIndex);

      if (charIndex < current.text.length) {
        charIndex += 1;
        timeout = window.setTimeout(typeLoop, 42 + Math.random() * 34);
        return;
      }

      label.textContent = current.label;
      value.textContent = current.value;
      timeout = window.setTimeout(() => {
        result.classList.add("show");
        timeout = window.setTimeout(() => {
          charIndex = 0;
          sampleIndex = (sampleIndex + 1) % samples.length;
          typeLoop();
        }, 1900);
      }, 350);
    };

    if (!prefersReduced) {
      typeLoop();
    } else if (textEl && label && value && result) {
      textEl.textContent = samples[0].text;
      label.textContent = samples[0].label;
      value.textContent = samples[0].value;
      result.classList.add("show");
    }

    return () => {
      window.removeEventListener("scroll", onScroll);
      observer?.disconnect();
      buttons.forEach((button) => button.removeEventListener("click", onPrivacyClick));
      if (timeout) window.clearTimeout(timeout);
    };
  }, []);

  return null;
}
