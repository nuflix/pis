import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

function getClient(shard: 'serverA' | 'serverB') {
  const cfg = shard === 'serverA'
    ? { url: process.env.SUPABASE_A_URL!, key: process.env.SUPABASE_A_API_KEY! }
    : { url: process.env.SUPABASE_B_URL!, key: process.env.SUPABASE_B_API_KEY! };
  return createClient(cfg.url, cfg.key);
}

export async function POST(req: NextRequest) {
  try {
    const { name, body, shard } = await req.json();
    if (!name || !body || !['serverA','serverB'].includes(shard)) {
      return NextResponse.json({ ok:false, error:'Bad request' }, { status: 400 });
    }
    const supabase = getClient(shard);
    const { error } = await supabase.from('messages').insert({ ime: name, poruka: body });
    if (error) throw error;
    return NextResponse.json({ ok:true, shard, pod: process.env.HOSTNAME || 'local' });
  } catch (e:any) {
    return NextResponse.json({ ok:false, error: e.message ?? 'unknown' }, { status: 500 });
  }
}

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const shard = searchParams.get("shard") as "serverA" | "serverB" | "all" | null;

  try {
    if (shard === "all") {
      const supabaseA = getClient("serverA");
      const supabaseB = getClient("serverB");

      const [a, b] = await Promise.all([
        supabaseA.from("messages").select("*").order("created_at", { ascending: false }),
        supabaseB.from("messages").select("*").order("created_at", { ascending: false }),
      ]);

      if (a.error) throw a.error;
      if (b.error) throw b.error;

      return NextResponse.json({ ok: true, shard: "all", messages: [...a.data, ...b.data] });
    }

    const chosen = shard === "serverA" ? "serverA" : shard === "serverB" ? "serverB" : "serverA";
    const supabase = getClient(chosen);
    const { data, error } = await supabase.from("messages").select("*").order("created_at", { ascending: false });
    if (error) throw error;

    return NextResponse.json({ ok: true, shard: chosen, messages: data });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: e.message ?? "unknown" }, { status: 500 });
  }
}
