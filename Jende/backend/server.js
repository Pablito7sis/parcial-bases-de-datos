import express from "express";
import cors from "cors";
import pkg from "pg";

const { Pool } = pkg;

const app = express();
app.use(cors());
app.use(express.json());

// --- Conexión directa a PostgreSQL ---
const pool = new Pool({
  user: "postgres",        
  password: "Pablito7617",
  host: "localhost",       
  port: 5432,              
  database: "proyecto"     
});

// --- Endpoint de prueba ---
app.get("/api/testdb", async (req, res) => {
  try {
    const result = await pool.query("SELECT current_database(), current_user");
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

import PDFDocument from "pdfkit";
import fs from "fs";

// --- Generar factura ---
app.get("/api/orders/:id/invoice", async (req, res) => {
  const { id } = req.params;

  try {
    // Obtener datos del pedido
    const order = await pool.query(
      `SELECT o.id, o.table_number, o.created_at, c.name as client_name, u.username as user_name
       FROM jende.orders o
       JOIN jende.clients c ON o.client_id = c.id
       JOIN jende.users u ON o.user_id = u.id
       WHERE o.id = $1`,
      [id]
    );

    if (order.rows.length === 0) {
      return res.status(404).json({ error: "Pedido no encontrado" });
    }

    const items = await pool.query(
      `SELECT p.name, p.price, oi.quantity, (p.price * oi.quantity) as total
       FROM jende.order_items oi
       JOIN jende.products p ON oi.product_id = p.id
       WHERE oi.order_id = $1`,
      [id]
    );

    // Crear PDF
    const doc = new PDFDocument();
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", `inline; filename=factura-${id}.pdf`);
    doc.pipe(res);

    // Encabezado
    doc.fontSize(20).text("☕ Café Jende", { align: "center" });
    doc.fontSize(12).text(`Factura #${id}`, { align: "right" });
    doc.text(`Fecha: ${order.rows[0].created_at}`);
    doc.text(`Cliente: ${order.rows[0].client_name}`);
    doc.text(`Atendido por: ${order.rows[0].user_name}`);
    doc.moveDown();

    // Items
    doc.fontSize(14).text("Detalle de Pedido:");
    items.rows.forEach((item) => {
      doc.text(
        `${item.quantity} x ${item.name} - $${item.price} = $${item.total}`
      );
    });

    // Total
    const total = items.rows.reduce((acc, i) => acc + Number(i.total), 0);
    doc.moveDown();
    doc.fontSize(16).text(`TOTAL: $${total}`, { align: "right" });

    // Finalizar
    doc.end();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
// --- Productos ---
app.get("/api/products", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM jende.products ORDER BY category, name");
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Registrar pedido ---
app.post("/api/orders", async (req, res) => {
  const { client_id, user_id, table_number, items } = req.body;
  try {
    await pool.query("CALL jende.registrar_pedido($1,$2,$3,$4)", [
      client_id,
      user_id,
      table_number,
      JSON.stringify(items)
    ]);
    res.status(201).json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Reporte ventas ---
app.get("/api/reports/ventas_totales", async (req, res) => {
  try {
    const result = await pool.query("SELECT jende.ventas_totales() AS total");
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Servidor ---
const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(`☕ Backend Café Jende corriendo en puerto ${PORT}`));
