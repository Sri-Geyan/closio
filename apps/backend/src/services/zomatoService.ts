import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

class ZomatoService {
  private userClients: Map<string, Client> = new Map();

  private async getOrCreateClient(userId: string): Promise<Client> {
    if (this.userClients.has(userId)) {
      return this.userClients.get(userId)!;
    }

    const transport = new StdioClientTransport({
      command: 'npx',
      args: ['mcp-remote', 'https://mcp-server.zomato.com/mcp']
    });

    const client = new Client(
      {
        name: 'closio-zomato-client',
        version: '1.0.0',
      },
      {
        capabilities: {},
      }
    );

    await client.connect(transport);
    this.userClients.set(userId, client);
    return client;
  }

  private parseToolResult(result: any): any {
    if (result && result.content && Array.isArray(result.content) && result.content.length > 0) {
      const textContent = result.content.find((c: any) => c.type === 'text');
      if (textContent && textContent.text) {
        try {
          return JSON.parse(textContent.text);
        } catch (e) {
          return { text: textContent.text };
        }
      }
    }
    return result;
  }

  async bindNumber(userId: string, phoneNumber: string) {
    const client = await this.getOrCreateClient(userId);
    const result = await client.callTool({
      name: 'bind_user_number',
      arguments: { phone_number: phoneNumber }
    });
    return this.parseToolResult(result);
  }

  async verifyCode(userId: string, code: string, stateId: string) {
    const client = await this.getOrCreateClient(userId);
    const result = await client.callTool({
      name: 'bind_user_number_verify_code',
      arguments: { code, state_id: stateId }
    });
    return this.parseToolResult(result);
  }

  async getRestaurants(userId: string, keyword: string, lat: number, lng: number) {
    const client = await this.getOrCreateClient(userId);
    const result = await client.callTool({
      name: 'get_restaurants_for_keyword',
      arguments: { keyword, lat, lng }
    });
    return this.parseToolResult(result);
  }

  async getMenu(userId: string, resId: number) {
    const client = await this.getOrCreateClient(userId);
    const result = await client.callTool({
      name: 'get_restaurant_menu_by_categories',
      arguments: { res_id: resId }
    });
    return this.parseToolResult(result);
  }

  async createCart(userId: string, resId: number, items: any[], addressId: string, paymentType: string) {
    const client = await this.getOrCreateClient(userId);
    const result = await client.callTool({
      name: 'create_cart',
      arguments: { res_id: resId, items, address_id: addressId, payment_type: paymentType }
    });
    return this.parseToolResult(result);
  }

  async checkoutCart(userId: string, cartId: string) {
    const client = await this.getOrCreateClient(userId);
    const result = await client.callTool({
      name: 'checkout_cart',
      arguments: { cart_id: cartId }
    });
    return this.parseToolResult(result);
  }
}

export const zomatoService = new ZomatoService();
