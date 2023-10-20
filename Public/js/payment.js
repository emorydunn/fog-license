// This is your test publishable API key.
const stripe = Stripe("pk_test_5JCEhDcc0sN6ci9NIGdEhjPr");

let elements;
let appBundleID;

const form = document.getElementById("payment-form");
const submitButton = document.getElementById("submit");

form.addEventListener("submit", handleSubmit);

initialize();
checkStatus();

const handleError = (error) => {
  const messageContainer = document.querySelector("#payment-message");
  messageContainer.textContent = error.message;
  submitButton.disabled = false;
};

async function initialize() {
  console.log("initialize payment elements");

  const checkoutIntentResponse = await fetch(window.location, {
    method: "CHECKOUT",
    headers: { "Content-Type": "application/json" },
  });
  const { bundleID, paymentOptions } = await checkoutIntentResponse.json();

  appBundleID = bundleID;
  elements = stripe.elements(paymentOptions);

  const paymentElementOptions = {
    layout: "tabs",
  };

  // Create and mount the Payment Element
  const paymentElement = elements.create("payment", paymentElementOptions);
  paymentElement.mount("#payment-element");
}

async function handleSubmit(e) {
  e.preventDefault();
  console.log("Submitting form");

  // setLoading(true);

  // Prevent multiple form submissions
  if (submitButton.disabled) {
    return;
  }

  // Disable form submission while loading
  submitButton.disabled = true;

  // Trigger form validation and wallet collection
  const { error: submitError } = await elements.submit();
  if (submitError) {
    handleError(submitError);
    return;
  }

  const { clientSecret } = await getPaymentIntent();

  console.log("Got secret: " + clientSecret);

  const { error } = await stripe.confirmPayment({
    elements,
    clientSecret,
    confirmParams: {
      return_url: "http://localhost:8080/app/" + appBundleID + "/complete",
    },
  });

  // This point will only be reached if there is an immediate error when
  // confirming the payment. Otherwise, your customer will be redirected to
  // your `return_url`. For some payment methods like iDEAL, your customer will
  // be redirected to an intermediate site first to authorize the payment, then
  // redirected to the `return_url`.
  if (error.type === "card_error" || error.type === "validation_error") {
    showMessage(error.message);
  } else {
    showMessage("An unexpected error occurred.");
  }

  submitButton.disabled = false;
}

async function getPaymentIntent() {
  const clientSecret = new URLSearchParams(window.location.search).get(
    "payment_intent_client_secret"
  );

  if (clientSecret) {
    console.log("Returning client secret from URL");
    return { clientSecret: clientSecret };
  }

  console.log("Creating new payment intent");

  const formData = {
    name: document.getElementById("name").value,
    email: document.getElementById("email").value,
    subscribe: document.getElementById("subscribe-check").checked,
  };

  // Create the PaymentIntent and obtain clientSecret
  const res = await fetch("/app/" + appBundleID + "/create-intent", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(formData),
  });

  return await res.json();
}

// Fetches the payment intent status after payment submission
async function checkStatus() {
  const statusMessage = new URLSearchParams(window.location.search).get(
    "status_message"
  );

  if (!statusMessage) {
    return;
  }

  showMessage(statusMessage);
}

// ------- UI helpers -------

function showMessage(messageText) {
  const messageContainer = document.querySelector("#payment-message");

  messageContainer.classList.remove("hidden");
  messageContainer.textContent = messageText;

  setTimeout(function () {
    messageContainer.classList.add("hidden");
    messageContainer.textContent = "";
  }, 4000);
}

// Show a spinner on payment submission
function setLoading(isLoading) {
  if (isLoading) {
    // Disable the button and show a spinner
    document.querySelector("#submit").disabled = true;
    document.querySelector("#spinner").classList.remove("hidden");
    document.querySelector("#button-text").classList.add("hidden");
  } else {
    document.querySelector("#submit").disabled = false;
    document.querySelector("#spinner").classList.add("hidden");
    document.querySelector("#button-text").classList.remove("hidden");
  }
}
