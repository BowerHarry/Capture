import { Button } from "../ui/button";
import { LogOut } from "lucide-react";
import { useAuth } from '../AuthContext';

export function ProfileAppHeader() {
  const { logout } = useAuth();

  return (
    <div className="flex items-center justify-end p-4 pb-2">
      <div className="flex items-center space-x-2">
        <Button variant="ghost" size="sm" onClick={logout} className="text-muted-foreground hover:text-foreground">
          <LogOut size={16} />
        </Button>
      </div>
    </div>
  );
}