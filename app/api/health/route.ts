import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json({
    ok: true,
    pod: process.env.HOSTNAME || 'local',
  });
}
