import { useEffect, useState } from "react";
import { getProducts, createOrder } from "./api";

function App() {
  const [products, setProducts] = useState([]);
  const [cart, setCart] = useState([]);

  useEffect(() => {
    getProducts().then(res => setProducts(res.data));
  }, []);

  const addToCart = (product) => {
    setCart([...cart, { product_id: product.id, quantity: 1 }]);
  };

  const sendOrder = async () => {
    const order = {
      client_id: 1,   // por ahora fijo
      user_id: 1,     // por ahora fijo
      table_number: "5",
      items: cart,
    };
    await createOrder(order);
    alert("✅ Pedido enviado!");
    setCart([]);
  };

  return (
    <div>
      <h1>☕ Café Jende</h1>

      <h2>Productos</h2>
      <ul>
        {products.map(p => (
          <li key={p.id}>
            {p.name} - ${p.price}  
            <button onClick={() => addToCart(p)}>Añadir</button>
          </li>
        ))}
      </ul>

      <h2>Carrito</h2>
      <ul>
        {cart.map((item, i) => (
          <li key={i}>
            Producto {item.product_id} x {item.quantity}
          </li>
        ))}
      </ul>

      <button onClick={sendOrder}>Enviar pedido</button>
    </div>
  );
}

export default App;