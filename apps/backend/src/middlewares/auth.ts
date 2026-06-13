import { Request, Response, NextFunction } from 'express';
import { createClient } from '@supabase/supabase-js';

declare global {
  namespace Express {
    interface Request {
      user?: any;
    }
  }
}

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.warn('Missing SUPABASE_URL or SUPABASE_ANON_KEY. Backend auth will fail.');
}

// Node.js 18 polyfill for WebSocket required by @supabase/supabase-js
import WebSocket from 'ws';
(global as any).WebSocket = WebSocket;

const supabase = createClient(supabaseUrl || '', supabaseAnonKey || '', {
  auth: { persistSession: false }
});

export const authenticateToken = async (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) return res.sendStatus(401);

  const { data, error } = await supabase.auth.getUser(token);
  
  if (error || !data.user) {
    console.error('Supabase Auth Error:', error);
    return res.sendStatus(403);
  }

  req.user = data.user;
  // Make sure we attach sub for compatibility with the rest of the app
  req.user.sub = data.user.id;
  
  next();
};
