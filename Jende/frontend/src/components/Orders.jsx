import React, { useEffect, useState } from "react";
import api from "./api"; 

export default function Orders() {
  const [orders, setOrders] = useState([]);

  useEffect(() => {
    api.get("/orders") // debes tener un endpoint GET /orders
      .then(res => setOrders(res.data))
      .catch(err => console.error(err));
  }, []);

  const handleInvoice = (orderId) => {
    window.open(`http://localhost:4000/api/orders/${orderId}/invoice`, "_blank");
  };

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-4">📋 Pedidos</h1>

      {orders.map(order => (
        <div 
          key={order.id} 
          className="flex justify-between items-center border-b py-2"
        >
          <span>
            Pedido #{order.id} - Mesa {order.table_number}
          </span>
          <button 
            onClick={() => handleInvoice(order.id)} 
            className="bg-blue-500 text-white px-4 py-1 rounded hover:bg-blue-600"
          >
            Imprimir Factura
          </button>
        </div>
      ))}
    </div>
  );
}
