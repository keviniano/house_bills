import { Controller } from "@hotwired/stimulus"

// Draws a Google chart from a JSON endpoint returning { type, cols, rows, options }.
export default class extends Controller {
  static values = { url: String }

  async connect() {
    const [ google, response ] = await Promise.all([ loadGoogleCharts(), fetch(this.urlValue) ])
    const data = await response.json()

    const table = new google.visualization.DataTable()
    data.cols.forEach(col => table.addColumn(...col))
    table.addRows(data.rows)

    const chart = new google.visualization.ChartWrapper({
      chartType: data.type,
      dataTable: table,
      options: { ...data.options, width: this.element.clientWidth, height: this.element.clientHeight }
    })
    chart.draw(this.element)
  }
}

let googleCharts

// Google retired google.com/jsapi; charts now load from gstatic.
function loadGoogleCharts() {
  googleCharts ||= new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = "https://www.gstatic.com/charts/loader.js"
    script.onload = () => {
      window.google.charts.load("current", { packages: [ "corechart" ] })
      window.google.charts.setOnLoadCallback(() => resolve(window.google))
    }
    script.onerror = reject
    document.head.appendChild(script)
  })
  return googleCharts
}
