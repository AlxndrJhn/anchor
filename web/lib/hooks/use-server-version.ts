import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api/client";

/** The version the server reports, once it has answered. */
export function useServerVersion(): string | undefined {
  const { data } = useQuery({
    queryKey: ["server-health"],
    queryFn: () => api.get("api/health").json<{ version?: string }>(),
    staleTime: 5 * 60 * 1000,
  });
  return data?.version;
}
