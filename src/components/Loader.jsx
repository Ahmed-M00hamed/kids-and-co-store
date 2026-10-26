export default function Loader({ label = "Loading..." }) {
    return (
        <div
            role="status"
            className="flex flex-col items-center justify-center gap-3 py-16 text-sm text-slate-500"
        >
            <span className="h-8 w-8 animate-spin rounded-full border-4 border-slate-200 border-t-blue-500" />
            <span>{label}</span>
        </div>
    );
}
