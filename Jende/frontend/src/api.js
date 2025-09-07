import axios from "axios";

const api = axios.create({
  baseURL: "/api", // gracias al proxy va a localhost:4000/api
});

// Obtener productos
export const getProducts = () => api.get("/products");

// Registrar pedido
export const createOrder = (order) => api.post("/orders", order);

// Reporte de ventas
export const getVentasTotales = () => api.get("/reports/ventas_totales");
