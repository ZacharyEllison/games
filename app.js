const games = [
	{
		id: "tic_tac_toe",
		name: "Tic Tac Toe",
		description: "Classic 3x3 play with a phone-first portrait layout.",
		tag: "Ready",
		url: "../tic_tac_toe/index.html",
		aspect: "9 / 16",
		icon: "../tic_tac_toe/Tic Tac Toe.icon.png",
	},
	{
		id: "flappy",
		name: "Flappy",
		description: "Tap or click to flap and hold altitude in a compact arcade loop.",
		tag: "New Export",
		url: "../flappy/index.html",
		aspect: "2 / 3",
		icon: "../flappy/Flappy.icon.png",
	},
];

const gameList = document.getElementById("game-list");
const gameFrame = document.getElementById("game-frame");
const frameShell = document.getElementById("frame-shell");
const playerHeading = document.getElementById("player-heading");
const viewerCopy = document.getElementById("viewer-copy");
const openLink = document.getElementById("open-link");

function safeAssetUrl(path) {
	return encodeURI(path);
}

function selectGame(gameId) {
	const game = games.find((item) => item.id === gameId) ?? games[0];
	playerHeading.textContent = game.name;
	viewerCopy.textContent = game.description;
	openLink.href = game.url;
	gameFrame.title = game.name;
	gameFrame.src = safeAssetUrl(game.url);
	frameShell.style.setProperty("--game-aspect", game.aspect);

	document.querySelectorAll(".game-card").forEach((card) => {
		card.classList.toggle("is-active", card.dataset.gameId === game.id);
		card.setAttribute("aria-selected", String(card.dataset.gameId === game.id));
	});

	window.location.hash = game.id;
}

function renderGames() {
	games.forEach((game) => {
		const button = document.createElement("button");
		button.type = "button";
		button.className = "game-card";
		button.dataset.gameId = game.id;
		button.setAttribute("role", "option");
		button.setAttribute("aria-selected", "false");
		button.innerHTML = `
			<img class="game-thumb" src="${safeAssetUrl(game.icon)}" alt="">
			<div>
				<p class="game-name">${game.name}</p>
				<p class="game-meta">${game.description}</p>
				<span class="game-tag">${game.tag}</span>
			</div>
		`;
		button.addEventListener("click", () => selectGame(game.id));
		gameList.appendChild(button);
	});
}

renderGames();
selectGame(window.location.hash.replace("#", ""));
