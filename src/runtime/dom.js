(function () {
	let size = window.innerWidth + 'x' + window.innerHeight;
	if (document.cookie.indexOf('#{BROWSER_VIEW_SIZE}=' + size) === -1) {
		document.cookie = '#{BROWSER_VIEW_SIZE}=' + size + '; path=/'
		window.location = ''
	}

	document.addEventListener('click', async (event) => {
		const element = event.target.closest('a[href], button, input:not([type="hidden"]), select, textarea, summary, [data-ore-onclick]')

		if (!element) return
		if (!element.hasAttribute('data-ore-onclick')) return
		const object_id = element.dataset.oreOnclick

		event.preventDefault()
		event.stopPropagation()

		const inputs = {};
		document.querySelectorAll('[data-ore-id]').forEach(el => {
			if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
				inputs[el.dataset.oreId] = el.value;
			}
		});

		const url = `/onclick/${object_id}`
		const response = await fetch(url, {
			method: 'POST', // Specify the method
			headers: {
				'Content-Type': 'application/json', // Inform the server the body is JSON
			}
		})
		const body = await response.text()
		console.log(`Response from ${url}: ${body}`)

		// const target_id = response.headers.get('X-Ore-Target-id')
		// console.log('X-Ore-Target-id: ', target_id)
		// document.querySelector(target).innerHTML = html
	})
})()
